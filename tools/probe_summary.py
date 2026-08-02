"""实验 v2：多次采样，统计 commentary 与 web_search 的共现（消除单次随机性）。"""
import io
import json
import urllib.request
from collections import Counter

with io.open('../agent-flutter-cli/config.json', encoding='utf-8') as f:
    cfg = json.load(f)
key = cfg['language_models']['responses']['deepseek']['api_key']
url = 'https://api.deepseek.com/v1/responses'


def run_once(extra):
    body = {
        'model': 'deepseek-v4-flash',
        'input': [{'role': 'user', 'content': '请务必使用网络搜索，搜索今天有哪些科技新闻，并列出 3 条'}],
        'tools': [{'type': 'web_search'}],
        'stream': True,
    }
    body.update(extra)
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
        method='POST',
    )
    stats = Counter()
    commentary = 0
    searches = 0
    with urllib.request.urlopen(req, timeout=180) as resp:
        for raw in resp:
            line = raw.decode('utf-8', errors='replace').strip()
            if not line.startswith('data:'):
                continue
            data = line[5:].strip()
            if data == '[DONE]':
                continue
            try:
                ev = json.loads(data)
            except Exception:
                continue
            t = ev.get('type', '?')
            stats[t] += 1
            if t == 'response.output_item.done':
                item = ev.get('item', {})
                if item.get('type') == 'message' and item.get('phase') == 'commentary':
                    commentary += 1
            if t == 'response.web_search_call.completed':
                searches += 1
    return commentary, searches


for label, extra in [
    ('① summary=detailed', {'reasoning': {'summary': 'detailed'}}),
    ('② 无 reasoning 参数', {}),
]:
    print(f'===== {label}（3 次采样） =====')
    for i in range(3):
        try:
            c, s = run_once(extra)
            print(f'  第{i+1}次: commentary={c}, web_search_completed={s}')
        except Exception as e:
            print(f'  第{i+1}次 ERROR: {type(e).__name__}: {str(e)[:150]}')
    print()
