"""抓取 DeepSeek Responses 完整事件流（含 web_search 全生命周期）写入 log 文件。

用法: py tools/capture_search_trace.py
输出: tools/search_trace2.log（完整原始事件流，含毫秒时间戳）
"""
import io
import json
import urllib.request
from collections import Counter
from datetime import datetime

LOG_PATH = 'tools/search_trace2.log'

with io.open('../agent-flutter-cli/config.json', encoding='utf-8') as f:
    cfg = json.load(f)
key = cfg['language_models']['responses']['deepseek']['api_key']
url = 'https://api.deepseek.com/v1/responses'

body = {
    'model': 'deepseek-v4-flash',
    'input': [{'role': 'user', 'content': '帮我搜索今天有哪些重要新闻，并简要列出 3 条'}],
    'tools': [{'type': 'web_search'}],
    'citations': {'enabled': True},
    'stream': True,
}

log = io.open(LOG_PATH, 'w', encoding='utf-8')
stats = Counter()


def w(line: str):
    log.write(f'[{datetime.now().strftime("%H:%M:%S.%f")[:-3]}] {line}\n')


w('=' * 80)
w(f'请求时间: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
w(f'请求 URL: {url}')
w(f'请求体: {json.dumps(body, ensure_ascii=False)}')
w('=' * 80)

req = urllib.request.Request(
    url,
    data=json.dumps(body).encode(),
    headers={
        'Authorization': f'Bearer {key}',
        'Content-Type': 'application/json',
    },
    method='POST',
)

try:
    with urllib.request.urlopen(req, timeout=300) as resp:
        w(f'HTTP {resp.status} {resp.reason}')
        for raw in resp:
            line = raw.decode('utf-8', errors='replace').rstrip('\r\n')
            if line.startswith('data:'):
                data = line[5:].strip()
                if data and data != '[DONE]':
                    try:
                        t = json.loads(data).get('type', '?')
                        stats[t] += 1
                    except Exception:
                        stats['<non-json>'] += 1
            w(line)
except Exception as e:
    w(f'ERROR: {type(e).__name__}: {str(e)[:500]}')
finally:
    w('=' * 80)
    w('事件类型统计:')
    for t, n in stats.most_common():
        w(f'  {t}: {n}')
    w(f'总事件行数: {sum(stats.values())}')
    w('=' * 80)
    log.close()

print(f'完成。完整事件流已写入 {LOG_PATH}，共 {sum(stats.values())} 个事件')
for t, n in stats.most_common(10):
    print(f'  {t}: {n}')
