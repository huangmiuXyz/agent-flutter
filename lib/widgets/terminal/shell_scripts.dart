/// Shell integration scripts for cursor movement support.
///
/// Each script makes the shell respond to Ctrl+X,Ctrl+G by reading a delta
/// value from a temp file and moving the cursor accordingly.
library;

// Placeholders in templates:
//   __CURSOR_PATH__  — absolute path to the cursor request temp file
//   __ESC__          — escape character (PowerShell only)
//   __BEL__          — bell character (PowerShell only)

const _pwshTemplate = r'''
function global:prompt {
  $exitCode = if ($?) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
  [Console]::Write("__ESC__]633;D;$exitCode__BEL__")
  "PS $($executionContext.SessionState.Path.CurrentLocation)> "
}

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
  Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+g' -ScriptBlock {
    try {
      $delta = [int](Get-Content -LiteralPath '__CURSOR_PATH__' -Raw)
      if ($delta -lt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar($null, -$delta)
      } elseif ($delta -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($null, $delta)
      }
    } catch {}
  }
}
''';

/// Returns a PowerShell integration script with placeholders replaced.
String pwshScript(String cursorPath) {
  const esc = '\x1b';
  const bel = '\x07';
  final escapedPath = cursorPath.replaceAll("'", "''");
  return _pwshTemplate
      .replaceAll('__ESC__', esc)
      .replaceAll('__BEL__', bel)
      .replaceAll('__CURSOR_PATH__', escapedPath);
}

const _zshTemplate = r'''
source ~/.zshrc 2>/dev/null

__agent_cursor_move() {
  local delta
  IFS= read -r delta < '__CURSOR_PATH__' || return
  [[ $delta == <-> || $delta == -<-> ]] || return
  (( CURSOR += delta ))
  (( CURSOR < 0 )) && CURSOR=0
  (( CURSOR > ${#BUFFER} )) && CURSOR=${#BUFFER}
}
zle -N __agent_cursor_move
bindkey -M emacs '^X^G' __agent_cursor_move 2>/dev/null
bindkey -M viins '^X^G' __agent_cursor_move 2>/dev/null

preexec() { printf '\033]633;C\007'; }
precmd() { printf '\033]633;D;%s\007' $?; }
''';

/// Returns a Zsh integration script with placeholders replaced.
String zshScript(String cursorPath) {
  final escapedPath = cursorPath.replaceAll("'", "'\"'\"'");
  return _zshTemplate.replaceAll('__CURSOR_PATH__', escapedPath);
}

const _bashTemplate = r'''
source ~/.bashrc 2>/dev/null

__agent_readline_prefix() {
  local LC_ALL=C
  __agent_prefix=${READLINE_LINE:0:READLINE_POINT}
}

__agent_readline_byte_length() {
  local LC_ALL=C
  __agent_length=${#__agent_target}
}

__agent_cursor_move() {
  local delta target character_length
  IFS= read -r delta < '__CURSOR_PATH__' || return
  [[ $delta =~ ^-?[0-9]+$ ]] || return

  __agent_readline_prefix
  target=$((${#__agent_prefix} + delta))
  character_length=${#READLINE_LINE}
  (( target < 0 )) && target=0
  (( target > character_length )) && target=$character_length

  __agent_target=${READLINE_LINE:0:target}
  __agent_readline_byte_length
  READLINE_POINT=$__agent_length
}
bind -m emacs-standard -x '"\C-x\C-g":__agent_cursor_move' 2>/dev/null
bind -m vi-insertion -x '"\C-x\C-g":__agent_cursor_move' 2>/dev/null

PROMPT_COMMAND='printf "\033]633;D;$?\007"'
''';

/// Returns a Bash integration script with placeholders replaced.
String bashScript(String cursorPath) {
  final escapedPath = cursorPath.replaceAll("'", "'\"'\"'");
  return _bashTemplate.replaceAll('__CURSOR_PATH__', escapedPath);
}
