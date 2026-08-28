#!/usr/bin/env bash
# 修补 cargokit 为 rust_builder 生成的 Android Gradle 脚本。
#
# 为什么需要：`flutter_rust_bridge_codegen integrate` 生成的 rust_builder/ 被
# .gitignore 忽略，每次重新生成都会带回两份与本项目构建环境不兼容的内容：
#   1. plugin.gradle 用 project.exec{} —— Gradle 9 已移除该 API，配置期直接失败。
#      必须注入 @Inject ExecOperations 并改用 execOperations.exec{}。
#   2. android/build.gradle 的 compileSdkVersion 33 / minSdkVersion 19 —— 低于
#      app 侧的 36 / flutter.minSdkVersion 24，AGP 要求插件不低于 app。
# .patches/code_forge 里的同一份文件早已打好这两个补丁；本脚本把等价改动
# 幂等地应用到 rust_builder，由 `make apk` / `make patch-cargokit` 自动执行。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_GRADLE="$ROOT/rust_builder/cargokit/gradle/plugin.gradle"
APP_GRADLE="$ROOT/rust_builder/android/build.gradle"

for f in "$PLUGIN_GRADLE" "$APP_GRADLE"; do
  if [ ! -f "$f" ]; then
    echo "patch-cargokit: 找不到 $f —— 请先执行 flutter_rust_bridge_codegen integrate" >&2
    exit 1
  fi
done

# ── 1. Gradle 9：project.exec → execOperations.exec ──
if grep -q 'execOperations' "$PLUGIN_GRADLE"; then
  echo "patch-cargokit: plugin.gradle 已是 execOperations，跳过"
else
  grep -q 'project\.exec {' "$PLUGIN_GRADLE" || {
    echo "patch-cargokit: plugin.gradle 里找不到 project.exec，结构已变化，请手工核对" >&2
    exit 1
  }
  # 在首个 @TaskAction 前插入注入点，然后把 project.exec 全部替换
  awk '
    !injected && /^    @TaskAction$/ {
      print "    @javax.inject.Inject"
      print "    abstract ExecOperations getExecOperations()"
      print ""
      injected = 1
    }
    { print }
  ' "$PLUGIN_GRADLE" > "$PLUGIN_GRADLE.tmp"
  sed 's/project\.exec {/execOperations.exec {/g' "$PLUGIN_GRADLE.tmp" > "$PLUGIN_GRADLE"
  rm -f "$PLUGIN_GRADLE.tmp"

  grep -q 'abstract ExecOperations getExecOperations()' "$PLUGIN_GRADLE" || {
    echo "patch-cargokit: ExecOperations 注入失败" >&2
    exit 1
  }
  ! grep -q 'project\.exec {' "$PLUGIN_GRADLE" || {
    echo "patch-cargokit: 仍残留 project.exec" >&2
    exit 1
  }
  echo "patch-cargokit: plugin.gradle 已改用 execOperations"
fi

# ── 2. 插件 SDK 版本对齐 app ──
sed -i '' -E \
  -e 's/^([[:space:]]*)compileSdkVersion [0-9]+$/\1compileSdkVersion 36/' \
  -e 's/^([[:space:]]*)minSdkVersion [0-9]+$/\1minSdkVersion 24/' \
  "$APP_GRADLE"
echo "patch-cargokit: android/build.gradle compileSdk=$(grep -E -o 'compileSdkVersion [0-9]+' "$APP_GRADLE" | head -1 | cut -d' ' -f2) minSdk=$(grep -E -o 'minSdkVersion [0-9]+' "$APP_GRADLE" | head -1 | cut -d' ' -f2)"
