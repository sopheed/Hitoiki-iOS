#!/usr/bin/env python3
"""Build one self-contained App Store kit. No upload or network operations."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import sys
import zipfile
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve()
KIT = HERE.parents[1]
FONT_DIR = Path('/System/Library/Fonts')

def font(size, weight='W6'):
    candidates = sorted(FONT_DIR.glob(f'* {weight}.ttc'))
    candidates = [p for p in candidates if 'ProN' not in p.name] or candidates
    if not candidates:
        candidates = [FONT_DIR/'Helvetica.ttc']
    return ImageFont.truetype(str(candidates[0]), size)

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip()+'\n', encoding='utf-8')

def esc(value):
    return html.escape(str(value), quote=True)

def screenshot_canvas(app, raw, size, lines, number):
    w,h=size
    bg=app['background'];ink=app['color']
    canvas=Image.new('RGB',size,bg)
    d=ImageDraw.Draw(canvas)
    # Quiet ornamental circles and a small editorial label.
    d.ellipse((w*.70,-w*.20,w*1.26,w*.36), fill=Image.blend(Image.new('RGB',(1,1),bg),Image.new('RGB',(1,1),ink),.055).getpixel((0,0)))
    margin=int(w*.075)
    eyebrow=font(int(w*.025),'W3')
    d.text((margin,int(h*.042)),app['product'].upper()+'  /  '+f'{number:02}',font=eyebrow,fill=ink)
    title_size=int(w*.064)
    while True:
        title=font(title_size)
        if d.textlength(lines[0],font=title) <= w-margin*2:break
        title_size-=1
    d.text((margin,int(h*.091)),lines[0],font=title,fill=ink)
    sub_size=int(w*.032)
    while True:
        sub=font(sub_size,'W3')
        if d.textlength(lines[1],font=sub)<=w-margin*2:break
        sub_size-=1
    d.text((margin,int(h*.141)),lines[1],font=sub,fill=ink)
    d.rounded_rectangle((margin,int(h*.182),margin+w*.10,int(h*.182)+int(w*.007)),radius=4,fill=ink)
    # Preserve the complete real screen and its aspect ratio; never crop controls.
    shot=raw.convert('RGB')
    maxw=int(w*.83); maxh=int(h*.755)
    ratio=min(maxw/shot.width,maxh/shot.height)
    shot=shot.resize((int(shot.width*ratio),int(shot.height*ratio)),Image.Resampling.LANCZOS)
    x=(w-shot.width)//2;y=int(h*.22)
    mask=Image.new('L',shot.size,0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,shot.width-1,shot.height-1),radius=int(w*.034),fill=255)
    shadow=Image.new('RGBA',size)
    ImageDraw.Draw(shadow).rounded_rectangle((x,y+12,x+shot.width,y+shot.height+12),radius=int(w*.034),fill=(0,30,18,55))
    shadow=shadow.filter(ImageFilter.GaussianBlur(int(w*.018)))
    canvas=Image.alpha_composite(canvas.convert('RGBA'),shadow).convert('RGB')
    canvas.paste(shot,(x,y),mask)
    return canvas

CSS='''*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:var(--bg);color:#233d33;font-family:-apple-system,BlinkMacSystemFont,"Hiragino Kaku Gothic ProN",sans-serif;line-height:1.85}a{color:var(--accent);text-underline-offset:4px}header,main,footer{max-width:1040px;margin:auto;padding:24px}header{display:flex;justify-content:space-between;align-items:center;gap:20px;border-bottom:1px solid #233d3316}header a{text-decoration:none;font-weight:700}nav{display:flex;gap:18px;font-size:14px;flex-wrap:wrap}.brand{display:flex;align-items:center;gap:12px}.brand img{width:44px;height:44px;border-radius:12px}.hero{display:grid;grid-template-columns:1.1fr .9fr;gap:48px;align-items:center;padding:48px 0}.eyebrow{letter-spacing:.18em;color:var(--accent);font-size:12px;font-weight:700}h1{font-size:clamp(30px,4vw,48px);line-height:1.4;letter-spacing:-.04em;margin:14px 0 24px}h2{font-size:23px;line-height:1.55}h3{font-size:18px}p{margin:12px 0}.lead{font-size:17px;color:#4e6057}.hero-image{width:min(100%,310px);justify-self:center;border-radius:24px;box-shadow:0 18px 48px #233d3314}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin:32px 0 54px}.card,details,.policy{background:#ffffffbb;border:1px solid #233d3314;border-radius:22px;padding:24px}.card .num{font-size:12px;letter-spacing:.14em;color:var(--accent)}.article{max-width:760px;padding-top:30px;padding-bottom:60px}.policy{margin:18px 0}.policy h2{font-size:20px}details{margin:14px 0}summary{font-weight:700;cursor:pointer}details p{color:#4e6057}.contact{margin-top:40px;border-top:1px solid #233d3316;padding-top:24px}.badge{display:inline-block;border:1px solid #233d3325;border-radius:100px;padding:5px 14px;font-size:13px;margin:8px 6px 0 0}.notice{background:#fff1cf;color:#6c4e13;padding:14px 20px;border-radius:14px;font-size:14px}footer{border-top:1px solid #233d3316;color:#647268;font-size:12px;padding-bottom:40px}footer nav{margin-bottom:16px}@media(max-width:700px){header{align-items:flex-start;flex-direction:column}.hero{grid-template-columns:1fr;padding:24px 0;gap:28px}.hero-image{max-width:255px}.cards{grid-template-columns:1fr;gap:12px}main{padding:20px}.card{padding:20px}nav{gap:12px}.article{padding-top:14px}}'''

def site(app, publisher, kit):
    folder=kit/'site';folder.mkdir(exist_ok=True)
    if publisher.get('site_layout') == 'single_page':
        for old in ['support.html','privacy.html']:
            (folder/old).unlink(missing_ok=True)
        assets=folder/'assets';assets.mkdir(exist_ok=True)
        for image in assets.glob('*.png'):image.unlink()
        for image in (kit/'site-assets').glob('*.png'):shutil.copy2(image,assets/image.name)
        site_catalog(json.loads((kit/'site-content.json').read_text()),publisher,folder/'index.html')
        write(folder/'README.md','# 共通の公開ページ\n\nindex.html と assets/ を公開先 '+publisher['site_base_url'].rstrip('/')+'/ に配置します。3アプリの紹介・サポート・プライバシーを1ページにまとめています。公開処理は利用者が行います。')
        return
    holder=publisher.get('copyright_holder','').strip()
    mail=publisher.get('contact_email','').strip()
    ready=holder and mail and publisher.get('site_base_url','').strip()
    notice='' if ready else '<p class="notice">公開前の設定が必要です。運営者名・問い合わせメール・公開URLを publisher.json に設定して再生成してください。</p>'
    contact=(f'<p>運営者：{esc(holder)}</p><p><a href="mailto:{esc(mail)}">{esc(mail)}</a></p>' if holder and mail else '<p>連絡先は公開前に設定します。</p>')
    catalog_url=publisher.get('site_base_url','').rstrip('/')
    catalog_link=f'<a href="{esc(catalog_url)}/">アプリ一覧</a>' if catalog_url else ''
    def page(title,body):
        return '<!doctype html>\n<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="'+esc(app['promotional_text'])+'"><meta name="referrer" content="no-referrer"><title>'+esc(title)+' | '+esc(app['name'])+'</title><style>:root{--accent:'+app['color']+';--bg:'+app['background']+'}'+CSS+'</style></head><body><header><a class="brand" href="index.html"><img src="assets/icon.png" alt="">'+esc(app['name'])+'</a><nav aria-label="ページ">'+catalog_link+'<a href="support.html">サポート</a><a href="privacy.html">プライバシー</a></nav></header><main>'+notice+body+'</main><footer><nav><a href="index.html">アプリについて</a><a href="support.html">サポート</a><a href="privacy.html">プライバシーポリシー</a></nav>© 2026 '+esc(holder or '運営者名を設定してください')+'</footer></body></html>'
    cards=''.join(f'<article class="card"><span class="num">0{i+1}</span><h2>{esc(t)}</h2><p>{esc(b)}</p></article>' for i,(t,b) in enumerate(app['features']))
    body=f'<section class="hero"><div><p class="eyebrow">{esc(app["eyebrow"])}</p><h1>{esc(app["tagline"])}</h1><p class="lead">{esc(app["promotional_text"])}</p><p class="badge">{esc(app["devices"])}</p><p class="badge">アカウント登録なし</p></div><img class="hero-image" src="assets/screenshot.png" alt="{esc(app["name"])}の実際の画面"></section><section class="cards">{cards}</section><section class="contact"><h2>使い方・お問い合わせ</h2><p>よくある質問は<a href="support.html">サポートページ</a>をご覧ください。</p>{contact}</section>'
    write(folder/'index.html',page('アプリについて',body))
    faq=''.join(f'<details><summary>{esc(t)}</summary><p>{esc(b)}</p></details>' for t,b in app['faq'])
    body=f'<article class="article"><p class="eyebrow">SUPPORT</p><h1>使い方とお問い合わせ</h1><p>{esc(app["name"])}の使い方と、よくある質問です。</p>{faq}<section class="contact"><h2>お問い合わせ</h2><p>不具合やご要望について、アプリのバージョン・機種・OS・起きたことをお知らせください。パスワードなどの秘密情報や、記録・写真の添付は不要です。</p>{contact}<p>対応時に受け取ったメールアドレスと内容は、お問い合わせへの返信と問題の調査に使用します。</p></section></article>'
    write(folder/'support.html',page('サポート',body))
    sections=''.join(f'<section class="policy"><h2>{i+1}. {esc(t)}</h2><p>{esc(b)}</p></section>' for i,(t,b) in enumerate(app['privacy']))
    common=f'<section class="policy"><h2>{len(app["privacy"])+1}. お問い合わせと方針の変更</h2><p>お問い合わせにより提供されたメールアドレスと内容は、返信と問題の調査に必要な範囲で使用します。不要になった内容は削除します。運営者から第三者へ販売したり、広告のために利用したりしません。法令に基づく対応が必要な場合を除き、ご本人の同意なく第三者に提供しません。</p><p>本方針を変更した場合は、このページでお知らせします。</p>{contact}</section><section class="policy"><h2>{len(app["privacy"])+2}. このWebサイトについて</h2><p>このWebサイトには、広告・アクセス解析ツール・独自のCookieを組み込んでいません。ページの配信に伴い、ホスティングサービスがIPアドレスや閲覧日時などをアクセスログに記録する場合があります。アプリ内の記録や写真を、このWebサイトへ送ることはありません。</p></section>'
    apple='<p><a href="https://www.apple.com/legal/privacy/jp/">Appleのプライバシーポリシー</a></p>' if app['key']=='parkingspot' else ''
    body=f'<article class="article"><p class="eyebrow">PRIVACY POLICY</p><h1>プライバシーポリシー</h1><p>対象アプリ：{esc(app["name"])}<br>適用日：{esc(publisher["policy_effective_date"])}</p><p>記録は端末内に保存し、運営者が提供する通信サーバーへ送信しません。広告対応版ではGoogle AdMobを利用します。広告に伴うデータの処理は以下をご確認ください。</p>{sections}{apple}{common}</article>'
    write(folder/'privacy.html',page('プライバシーポリシー',body))
    assets=folder/'assets';assets.mkdir(exist_ok=True)
    shutil.copy2(kit/'icons/AppIcon.png',assets/'icon.png')
    shots=sorted((kit/'screenshots/iphone-large').glob('*.png'))
    if shots:shutil.copy2(shots[0],assets/'screenshot.png')
    write(folder/'README.md',f'''# 公開するページ

この `site/` のHTMLと `assets/` を、公開先 `{publisher.get('site_base_url','').rstrip('/')}/{app['key']}/` に配置します。READMEや設定ファイルをWeb公開する必要はありません。公開処理は利用者が行います。

- `index.html`: マーケティングURL
- `support.html`: サポートURL
- `privacy.html`: プライバシーポリシーURL
- `assets/`: 必要な画像（削除しないでください）

外部フォント・解析・Cookie・フォームは使いません。未設定の連絡先がある間は公開準備中の表示が出ます。publisher.json の設定後に再生成してください。サーバー側のアクセスログ・Cookie・解析を追加した場合は方針の見直しが必要です。
''')

def site_catalog(apps, publisher, output):
    """One public page for all app descriptions, support and privacy."""
    mail=publisher.get('contact_email','').strip()
    holder=publisher.get('copyright_holder','').strip()
    short={'hitoiki':'ひといき','wordpet':'ワードペット','parkingspot':'ParkingSpot'}
    cards=[]
    for app in apps:
        key=esc(app['key']);name=esc(short[app['key']])
        cards.append(f'''<article class="app" id="{key}" style="--accent:{esc(app['color'])};--card-bg:{esc(app['background'])}"><img class="icon" src="assets/{key}-icon.png" width="88" height="88" alt=""><p class="device">{esc(app['devices'])}</p><h2>{name}</h2><p class="tagline">{esc(app['tagline'])}</p><p class="description">{esc(app['promotional_text'])}</p><nav aria-label="{name}のご案内"><a href="#support">お問い合わせ</a><a href="#privacy">プライバシー</a></nav></article>''')
    stored=''.join(f'<li><strong>{esc(short[a["key"]])}</strong>：{esc(a["privacy"][0][1])}</li>' for a in apps)
    contact=f'<a href="mailto:{esc(mail)}">{esc(mail)}</a>' if mail else '連絡先は公開前に設定します。'
    styles='''*{box-sizing:border-box}html{color-scheme:light;scroll-padding-top:24px}body{margin:0;background:#f7f8f3;color:#233d33;font-family:-apple-system,BlinkMacSystemFont,"Hiragino Kaku Gothic ProN",sans-serif;line-height:1.85}a{color:inherit;text-underline-offset:4px}a:focus-visible,summary:focus-visible{outline:3px solid #126a65;outline-offset:5px}header,main,footer{max-width:1120px;margin:auto;padding:24px}header{display:flex;align-items:center;justify-content:space-between;gap:16px;border-bottom:1px solid #233d3317;font-size:14px}.brand{font-weight:750;letter-spacing:.12em;text-decoration:none}nav{display:flex;flex-wrap:wrap;gap:20px}.intro{padding:44px 0 24px}.eyebrow{font-size:12px;letter-spacing:.18em;color:#537265;font-weight:700}h1{font-size:clamp(30px,4.5vw,50px);letter-spacing:-.04em;line-height:1.5;margin:12px 0 18px}.lead{color:#536359;font-size:17px;max-width:720px}.apps{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px;margin:20px 0 56px}.app{display:flex;flex-direction:column;align-items:flex-start;background:var(--card-bg);border:1px solid #233d3312;border-radius:26px;padding:28px;min-width:0}.icon{width:88px;height:88px;border-radius:22px;box-shadow:0 10px 25px #233d3312}.device{font-size:11px;color:#52665b;margin:24px 0 6px}h2{font-size:25px;line-height:1.45;margin:0 0 16px}.app h2{margin-bottom:10px}.tagline{font-size:16px;font-weight:650;line-height:1.75;margin:0 0 12px}.description{font-size:14px;color:#4f6257;margin:0 0 24px}.app nav{font-size:12px;margin-top:auto;gap:16px}.section{border-top:1px solid #233d331a;padding:34px 0 42px}.section p,.section li{font-size:14px;color:#4c6054;max-width:850px}.email{font-size:18px!important;font-weight:650}.email a{overflow-wrap:anywhere;color:#126a65}details{background:#ffffffb8;border:1px solid #233d3313;border-radius:14px;padding:16px 20px;max-width:850px;margin:12px 0}summary{cursor:pointer;font-size:14px;font-weight:650}details p{margin-bottom:0}h3{font-size:16px;margin:28px 0 8px}ul{padding-left:22px}li{margin-bottom:12px}footer{font-size:12px;color:#65766c;border-top:1px solid #233d3317;padding-bottom:36px}footer p{margin-bottom:0}@media(max-width:760px){header,main,footer{padding-left:20px;padding-right:20px}header{align-items:flex-start;flex-direction:column;gap:12px}header nav{font-size:12px;gap:16px}.intro{padding-top:22px}.apps{grid-template-columns:1fr;gap:18px;margin-bottom:30px}.app{padding:26px}.lead{font-size:15px}h1{font-size:clamp(27px,7vw,38px)}.section{padding:28px 0 32px}.email{font-size:17px!important}}'''
    body='''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="ひといき、ワードペット、ParkingSpot。3つのアプリの紹介、お問い合わせ、プライバシーポリシーをまとめています。"><meta name="referrer" content="no-referrer"><title>毎日に、小さな相棒を。 | アプリとサポート</title><style>'''+styles+'''</style></head><body><header><a class="brand" href="#top">PERSONAL APPS</a><nav aria-label="ページ"><a href="#apps">アプリ</a><a href="#support">サポート</a><a href="#privacy">プライバシー</a></nav></header><main id="top"><section class="intro"><p class="eyebrow">FOR YOUR EVERYDAY</p><h1>毎日に、<br>小さな相棒を。</h1><p class="lead">自分のペースも、ことばと遊ぶ時間も、車を停めてからの帰り道も。<br>毎日にそっと手を貸す、3つのアプリです。</p></section><section class="apps" id="apps" aria-label="アプリ一覧">'''+''.join(cards)+'''</section><section class="section" id="support"><p class="eyebrow">SUPPORT</p><h2>使い方・お問い合わせ</h2><p>不具合やご要望は、アプリ名・バージョン・機種・起きたことを添えて、下記までお知らせください。パスワードなどの秘密情報や、記録・写真の添付は不要です。</p><p class="email">'''+contact+'''</p><details><summary>通知が届かないとき</summary><p>ひといき・ParkingSpotでは、端末の通知許可と集中モードをご確認ください。Apple Watchへの通知は、端末の利用状態とWatchアプリの通知ミラーリング設定によって変わります。アプリを開いて、進行中の記録と通知設定もご確認ください。</p></details><details><summary>ワードペットで次のゲームを始められないとき</summary><p>ゲームのあとはおせわが必要です。あかちゃんは2回、成長後は3回のおせわで次のゲームを遊べます。10分遊ぶと10分の休憩が入り、アプリを閉じている間も休憩時間は進みます。</p></details><details><summary>Apple Watchでできること</summary><p>ひといきはiPhoneで飲み会を開始し、Watchで時間の確認、お水・お酒の記録、おひらきができます。ParkingSpotはWatchから現在地の保存、時間の確認、徒歩案内、駐車の終了ができます。ペア端末が通信できるときに記録が同期され、写真はWatchへ同期しません。ワードペットはiPhone用です。</p></details><p>ParkingSpotの地図・検索・徒歩ルートには通信が必要です。位置情報を使えない場合も、iPhoneの地図上で場所を選んで保存できます。ひといきのチェックは気分を切り替える遊びで、酔い具合や運転の可否を判定するものではありません。飲酒後は運転しないでください。</p></section><section class="section" id="privacy"><p class="eyebrow">PRIVACY POLICY</p><h2>プライバシーポリシー</h2><p>対象：ひといき・ワードペット・ParkingSpot<br>運営者：'''+esc(holder or '運営者名を設定してください')+'''<br>適用日：'''+esc(publisher['policy_effective_date'])+'''</p><p>アカウント登録や運営者の通信サーバーはありません。アプリ内の記録は端末に保存します。広告対応版ではGoogle AdMobによるバナー広告を表示します。</p><h3>端末内に保存するもの</h3><ul>'''+stored+'''</ul><h3>通信・権限・共有</h3><p>ひといきとParkingSpotは、Appleの端末間連携機能で、ペアリングしたiPhoneとApple Watchの記録を同期します。写真はWatchへ送りません。CSVや駐車場所を共有する場合は、利用者が選んだ保存先・共有先へ情報を渡します。ワードペットの読み上げには、OSの音声機能を使います。</p><p>ParkingSpotの地図・検索・住所取得・徒歩ルートにはAppleのサービスを使い、検索語や地点などのリクエストがAppleに送られます。バックグラウンドで継続して位置を追跡する機能はありません。<a href="https://www.apple.com/legal/privacy/jp/">Appleのプライバシーポリシー</a>もご確認ください。</p><p>通知は利用者が設定したお知らせに、位置情報はParkingSpotの現在地表示・保存・案内に使います。ひといきのカメラは利用者が選んだ写真チェックにだけ使います。写真の選択にはOSの写真ピッカーを使い、保存時に元の位置情報などのメタデータを引き継がない画像に変換します。ワードペットは位置情報・カメラ・マイク・連絡先へのアクセスを求めません。</p><h3>バナー広告（広告対応版）</h3><p>広告対応版ではGoogle AdMobによるバナー広告を表示します。広告配信、不正防止、配信計測のため、IPアドレス（おおよその地域の推定に使われる場合があります）、端末や広告の識別情報、広告の表示・操作情報、クラッシュや性能などの診断情報がGoogleへ送信される場合があります。パーソナライズ広告を無効にし、IDFAの利用許可は求めません。端末の位置情報を広告へ渡さず、SDKによる端末の位置情報取得も無効にしています。アプリ内の記録・写真・名前・学習状況は広告へ渡しません。必要な地域では同意画面を表示し、「せってい／Settings」から必要に応じて同意内容を変更できます。広告を取得できなくても、アプリの機能は利用できます。<a href="https://policies.google.com/privacy">Googleのプライバシーポリシー</a>もご確認ください。</p><p>ワードペットの広告には、子ども向けの配信制限と全年齢向けの内容フィルターを設定しています。ゲーム中・休憩中・ストーリーの表示中には広告を表示しません。ひといきのチェック・撮影・記録入力中、ParkingSpotの登録・検索・ルート画面、Apple Watchアプリにも広告は表示しません。広告SDKを含まない以前のバージョンでは、広告に伴う送信はありません。</p><h3>保存・削除・バックアップ</h3><p>ひといきとParkingSpotの記録・添付写真は、アプリ内の履歴から削除できます。ワードペットを含め、アプリを削除すると、その端末内のアプリデータも削除されます。OSの設定によっては端末のバックアップに含まれる場合があります。アプリ独自のiPhone・iPad間のクラウド同期はありません。</p><h3>お問い合わせとこのWebサイト</h3><p>お問い合わせで提供されたメールアドレスと内容は、返信と問題の調査に使用し、不要になった内容は削除します。広告に利用したり第三者へ販売したりしません。法令に基づく対応が必要な場合を除き、本人の同意なく第三者に提供しません。</p><p>このWebサイトには広告・アクセス解析ツール・独自のCookieを組み込んでいません。ページの配信に伴い、ホスティングサービスがIPアドレスや閲覧日時などをアクセスログに記録する場合があります。アプリ内の記録や写真を、このWebサイトへ送ることはありません。</p><p>本方針を変更する場合は、このページでお知らせします。お問い合わせ：'''+contact+'''</p></section></main><footer><nav aria-label="フッター"><a href="#top">ページの先頭</a><a href="#support">お問い合わせ</a><a href="#privacy">プライバシー</a></nav><p>© 2026 '''+esc(holder or '運営者名を設定してください')+'''</p></footer></body></html>'''
    write(output,body)

def build(kit, strict=False, render_images=True):
    app=json.loads((kit/'app.json').read_text())
    pub=json.loads((kit/'publisher.json').read_text())
    repo=kit.parent
    for name,source in app['icons'].items():
        target=kit/'icons'/name;target.parent.mkdir(exist_ok=True)
        original=repo/source
        # A packaged kit can regenerate from its included icons without repo access.
        if original.exists(): Image.open(original).convert('RGB').save(target,optimize=True)
        elif not target.exists():raise FileNotFoundError(original)
    for group,size in ([('iphone-large',(1320,2868)),('iphone-medium',(1206,2622)),('ipad-13',(2064,2752))] if render_images else []):
        source=kit/'screenshots/raw'/('ipad-13' if group=='ipad-13' else 'iphone')
        files=sorted(source.glob('*.png'))
        if not files:continue
        out=kit/'screenshots'/group;out.mkdir(parents=True,exist_ok=True)
        for i,p in enumerate(files):
            if p.stem not in app['captions']:continue
            screenshot_canvas(app,Image.open(p),size,app['captions'][p.stem],i+1).save(out/p.name,optimize=True)
    base=pub.get('site_base_url','').rstrip('/')
    url=lambda page: ((base+'/' + {'support':'#support','index':'','privacy':'#privacy'}[page]) if pub.get('site_layout')=='single_page' else f'{base}/{app["key"]}/{page}.html') if base else ''
    metadata={'01_app_name':app['name'],'02_subtitle':app['subtitle'],'03_promotional_text':app['promotional_text'],'04_keywords':app['keywords'],'05_description':app['description'],'06_whats_new':app['whats_new'],'07_support_url':url('support') or app.get('store_defaults',{}).get('support_url',''),'08_marketing_url':url('index'),'09_copyright':f'2026 {pub["copyright_holder"]}' if pub['copyright_holder'] else app.get('store_defaults',{}).get('copyright',''), '10_review_notes':app['review_notes'],'11_privacy_policy_url':url('privacy')}
    for key,value in metadata.items():write(kit/'metadata/ja'/f'{key}.txt',value)
    site(app,pub,kit)
    report={'generated':app.get('release_prepared_on','2026-11-04'),'app':app['name'],'version':app['version'],'build':app['build'],'checks':[],'assets':[],'pending':[]}
    def check(name,ok,detail):report['checks'].append({'name':name,'pass':bool(ok),'detail':detail})
    check('personal_bundle_id',app['bundle'].startswith('eijirou.'),app['bundle'])
    sku=app.get('app_store_connect',{}).get('sku','')
    check('sku_uses_personal_namespace',sku==app['bundle'] or sku.startswith(app['bundle']+'.'),sku)
    if app['watch_bundle']:
        check('watch_bundle_id',app['watch_bundle']==app['bundle']+'.watchkitapp',app['watch_bundle'])
    for key,limit in [('01_app_name',30),('02_subtitle',30),('03_promotional_text',170),('04_keywords',100),('05_description',4000),('06_whats_new',4000),('10_review_notes',4000)]:
        value=metadata[key];count=len(value.encode('utf-8')) if key=='04_keywords' else len(value)
        check(key,count<=limit,f'{count}/{limit}'+(' UTF-8 bytes' if key=='04_keywords' else ' characters'))
    groups={'iphone-large':(1320,2868),'iphone-medium':(1206,2622)}
    if app['key']=='parkingspot':groups['ipad-13']=(2064,2752)
    if app['watch_bundle']:groups['watch']=(416,496)
    for group,size in groups.items():
        paths=sorted((kit/'screenshots'/group).glob('*.png'))
        check('screenshot count '+group,1<=len(paths)<=10,str(len(paths)))
        for p in paths:
            im=Image.open(p)
            check(str(p.relative_to(kit)),im.size==size and im.mode=='RGB',f'{im.size} {im.mode}')
    for p in sorted((kit/'icons').glob('*.png')):
        im=Image.open(p);check(str(p.relative_to(kit)),im.size==(1024,1024) and im.mode=='RGB',f'{im.size} {im.mode}')
    for k in ['site_base_url','contact_email','copyright_holder']:
        if not pub.get(k,'').strip():report['pending'].append('publisher.json: '+k)
    if base:check('site_base_url',base.startswith('https://') and '<' not in base and 'example.' not in base,'HTTPS, actual public URL required; not fetched by builder')
    if pub.get('contact_email'):check('contact_email',bool(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',pub['contact_email'])),'Email syntax')
    for k,v in pub.get('review_contact',{}).items():
        if not v.strip():report['pending'].append('Review contact: '+k)
    if not pub.get('rights_confirmed',{}).get(app['key']):report['pending'].append('Applicant must confirm content/icon/screenshot rights')
    if app['key']=='wordpet' and not pub.get('wordpet_personal_team_confirmed'):report['pending'].append('WordPet personal release Bundle ID / Team confirmation')
    for key, confirmed in pub.get('release_confirmations', {}).get(app['key'], {}).items():
        if not confirmed: report['pending'].append('Release confirmation: ' + key)
    if app['key'] not in pub.get('release_confirmations', {}):
        report['pending'].append('Release confirmations missing')
    report['assets_pass']=all(c['pass'] for c in report['checks'])
    report['submission_ready']=report['assets_pass'] and not report['pending']
    # Visual contact sheet; the labels show upload order. Not a submission asset.
    sheetfiles=sorted((kit/'screenshots/iphone-large').glob('*.png'))
    if sheetfiles:
        thumbw=220;thumbh=478;sheet=Image.new('RGB',(thumbw*len(sheetfiles),thumbh+52),app['background'])
        d=ImageDraw.Draw(sheet)
        for i,p in enumerate(sheetfiles):
            im=Image.open(p);im.thumbnail((thumbw,thumbh));sheet.paste(im,(i*thumbw,0));d.text((i*thumbw+10,thumbh+14),p.stem,font=font(14,'W3'),fill=app['color'])
        sheet.save(kit/'screenshots/CONTACT-SHEET.jpg',quality=88)
    for directory in ['metadata','icons','screenshots','site']:
        for p in sorted((kit/directory).rglob('*')):
            if p.is_file():report['assets'].append({'path':str(p.relative_to(kit)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    write(kit/'reports/validation.json',json.dumps(report,ensure_ascii=False,indent=2))
    failed=[c for c in report['checks'] if not c['pass']]
    write(kit/'reports/VALIDATION.md','# 検証結果\n\n生成日: '+report['generated']+'\n\n'+('画像・文字数の検証: PASS' if not failed else '画像・文字数の検証: FAIL')+'\n\n'+ '\n'.join(f'- {c["name"]}: {c["detail"]}' for c in report['checks'][:7])+'\n\n提出前に必要な設定:\n\n'+'\n'.join('- '+p for p in report['pending'])+'\n\n詳細とSHA-256は validation.json。公開URLの到達性、署名・提出・ストア承認はこの検証の対象外です。')
    dist=kit/'dist';dist.mkdir(exist_ok=True)
    filename=dist/f'{app["product"]}-AppStore-Kit-{app["version"]}-{app["build"]}.zip'
    with zipfile.ZipFile(filename,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(kit.rglob('*')):
            if p.is_file() and 'dist' not in p.relative_to(kit).parts and '__pycache__' not in p.parts:
                z.write(p,f'{app["product"]}-AppStore-Kit/{p.relative_to(kit)}')
    print(f'{app["product"]}: assets={"PASS" if report["assets_pass"] else "FAIL"}, pending={len(report["pending"])}, zip={filename}')
    for c in failed:print('FAIL:',c)
    if failed or (strict and report['pending']):return 2
    return 0

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kit',type=Path,default=KIT)
    parser.add_argument('--strict',action='store_true',help='Fail also for unresolved submission settings')
    parser.add_argument('--skip-images',action='store_true',help='Repackage unchanged images after documentation changes')
    args=parser.parse_args()
    sys.exit(build(args.kit.resolve(),args.strict,not args.skip_images))
