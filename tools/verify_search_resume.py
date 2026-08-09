"""验证 DeepSeek Responses API 是否支持回传 web_search_call 恢复搜索结果。

实验设计：
- 轮1：web_search 搜新闻，只列标题（不输出任何细节）
- 轮2a（对照组）：只回传 assistant 文本 → 追问标题对应的报道细节
- 轮2b（实验组）：回传 assistant 文本 + web_search_call item → 同样追问

若 2b 能答出细节（2a 答不出），说明服务端真的按 id 恢复了搜索结果。

用法: py tools/verify_search_resume.py
"""
import io
import json
import urllib.request

with io.open('../agent-flutter-cli/config.json', encoding='utf-8') as f:
    cfg = json.load(f)
key = cfg['language_models']['responses']['deepseek']['api_key']
url = 'https://api.deepseek.com/v1/responses'


def call(body):
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
        method='POST',
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.loads(resp.read().decode())


def extract_output(output):
    """按类型拆出输出 items：assistant 消息文本 / web_search_call / 其他。"""
    text = ''
    search_calls = []
    others = []
    for item in output:
        t = item.get('type')
        if t == 'message':
            for part in item.get('content', []):
                if part.get('type') == 'output_text':
                    text += part.get('text', '')
        elif t == 'web_search_call':
            search_calls.append(item)
        else:
            others.append(item)
    return text, search_calls, others


# ── 轮1：搜索，只列标题 ──
print('== 轮1: 搜索 ==')
r1 = call({
    'model': 'deepseek-v4-flash',
    'input': [{'role': 'user',
               'content': '请使用网络搜索获取今天的重要新闻，然后只列出 3 条新闻的标题，'
                          '不要输出任何标题之外的细节、时间、地点或数字。'}],
    'tools': [{'type': 'web_search'}],
    'stream': False,
})
t1, calls1, _ = extract_output(r1.get('output', []))
print(f'轮1回答: {t1!r}')
print(f'轮1 web_search_call items: {json.dumps(calls1, ensure_ascii=False)}')
assert calls1, '轮1未产生 web_search_call！'

# ── 轮2 追问：细节只有搜索结果原文里才有 ──
PROBE = ('现在请回答：以上 3 条标题中，第一条新闻的报道里提到的具体细节是什么？'
         '（比如地点、日期、金额、人物、数字等）\n'
         '注意：只能基于你上下文里搜索结果的原文回答；'
         '如果你在上下文中看不到搜索结果原文，请直接回答"看不到搜索结果原文"，不要编造。')
assistant_item = {'role': 'assistant', 'content': [{'type': 'output_text', 'text': t1}]}
probe_item = {'role': 'user', 'content': PROBE}

# ── 轮2a：对照组（不回传 web_search_call）──
print('\n== 轮2a: 对照组（仅 assistant 文本）==')
r2a = call({
    'model': 'deepseek-v4-flash',
    'input': [
        {'role': 'user', 'content': '请使用网络搜索获取今天的重要新闻，然后只列出 3 条新闻的标题，不要输出任何标题之外的细节、时间、地点或数字。'},
        assistant_item,
        probe_item,
    ],
    'stream': False,
})
t2a, calls2a, _ = extract_output(r2a.get('output', []))
print(f'轮2a回答: {t2a!r}')

# ── 轮2b：实验组（回传 web_search_call item）──
print('\n== 轮2b: 实验组（回传 web_search_call）==')
r2b = call({
    'model': 'deepseek-v4-flash',
    'input': [
        {'role': 'user', 'content': '请使用网络搜索获取今天的重要新闻，然后只列出 3 条新闻的标题，不要输出任何标题之外的细节、时间、地点或数字。'},
        assistant_item,
        *calls1,   # 完整回传：id + status + action
        probe_item,
    ],
    'stream': False,
})
t2b, calls2b, _ = extract_output(r2b.get('output', []))
print(f'轮2b回答: {t2b!r}')

print('\n==== 结论 ====')
print('对照(2a) 能答出细节:', '看不到' not in t2a and len(t2a) > 20)
print('实验(2b) 能答出细节:', '看不到' not in t2b and len(t2b) > 20)
print('2b 明显优于 2a 且含具体细节 → 服务端恢复了搜索结果')
