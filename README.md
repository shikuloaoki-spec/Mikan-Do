# 供養アーカイブ / Kuyo Archive

> 没になったキャラクター設定たちの、安らかな眠りを。  
> ファンの声があれば、いつかまた目覚めるかもしれない。

VTuber・歌い手が「ボツにしたキャラ設定・衣装案・活動名・世界観」を供養し、ファンが復活投票できるコミュニティアーカイブです。

**GitHub Pages（完全無料）でホスティングできます。**

---

## 機能一覧

| 機能 | 説明 |
|------|------|
| 📜 アーカイブ | カテゴリ・フィルター・ソート・全文検索 |
| 🔥 復活ランキング | 投票数順リアルタイムランキング |
| 🕯 設定を供養する | 3ステップ投稿フォーム（画像アップロード対応）|
| 👑 殿堂入り | 復活が決まった設定の記念展示 |
| 🗳 投票 | ログイン不要で投票可能（ログイン時は永続化）|
| 💬 コメント | 匿名＆ログインユーザーどちらでも投稿可 |
| 🌐 多言語 | 日本語 / English 切替 |
| ⚡ リアルタイム | Supabase Realtime で投票数が即時反映 |

---

## セットアップ手順

### 1. リポジトリをフォーク

```bash
# GitHubでこのリポジトリをForkしてから
git clone https://github.com/YOUR_USERNAME/kuyo-archive.git
cd kuyo-archive
```

---

### 2. Supabase プロジェクト作成

1. [supabase.com](https://supabase.com) でアカウント作成・新規プロジェクト作成
2. **SQL Editor** を開き、`supabase/schema.sql` の内容を全てコピー＆ペーストして実行
3. **Storage → New Bucket** で以下を作成：
   - Bucket name: `post-images`
   - Public bucket: **ON**

**プロジェクトの認証情報を控えておく：**

- `Settings → API` → **Project URL** → `SUPABASE_URL`
- `Settings → API` → **anon public** key → `SUPABASE_ANON_KEY`

---

### 3. X (Twitter) OAuth の設定

1. [developer.x.com](https://developer.x.com) でアプリ作成（無料の Basic アクセスで OK）
2. **User authentication settings** を有効化：
   - OAuth 2.0: **ON**
   - Type of App: **Web App**
   - Callback URL: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - Website URL: `https://YOUR_USERNAME.github.io/kuyo-archive`
3. **Supabase Dashboard → Authentication → Providers → Twitter** を開き：
   - Twitter を **Enable**
   - X の `Client ID` と `Client Secret` を貼り付け → Save

---

### 4. GitHub Secrets の設定

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** で2つ追加：

| Secret 名 | 値 |
|-----------|-----|
| `SUPABASE_URL` | `https://xxxxxxxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

---

### 5. GitHub Pages の有効化

リポジトリの **Settings → Pages**：

- Source: **GitHub Actions**
- Branch は自動で設定されます

---

### 6. デプロイ

```bash
git add .
git commit -m "initial setup"
git push origin main
```

GitHub Actions が自動で実行され、約1〜2分後に  
`https://YOUR_USERNAME.github.io/kuyo-archive` でアクセスできます。

---

## ローカル開発

Supabase の認証情報を直接 `index.html` に書き込んでから、任意のローカルサーバーで起動：

```bash
# Python
python3 -m http.server 8080

# Node.js
npx serve .

# VS Code
# Live Server 拡張機能でも OK
```

> ⚠️ `__SUPABASE_URL__` と `__SUPABASE_ANON_KEY__` プレースホルダーのままだと動きません。  
> ローカル開発時は `index.html` 内を直接書き換えてください（本番commitの前に戻すこと）。

---

## ディレクトリ構成

```
kuyo-archive/
├── index.html              # メインアプリ（HTML + CSS + JS 完結）
├── .github/
│   └── workflows/
│       └── deploy.yml      # GitHub Pages 自動デプロイ
├── supabase/
│   └── schema.sql          # DB スキーマ・RLS・トリガー定義
└── README.md
```

---

## データベース構成

```
profiles        ← auth.users と 1:1、Twitter情報を保存
posts           ← 供養された設定
  └── tags[]    ← PostgreSQL配列型
votes           ← post_id + user_id のユニーク制約
comments        ← post に対するファンコメント
```

投票数・コメント数は PostgreSQL トリガーで `posts.vote_count` / `posts.comment_count` に自動集計されます。

---

## Supabase RLS（Row Level Security）ポリシー概要

| テーブル | 読み取り | 書き込み |
|---------|---------|---------|
| profiles | 全員 | 本人のみ |
| posts | 全員 | 作成者のみ |
| votes | 全員 | 認証ユーザー（自分の分のみ削除可） |
| comments | 全員 | 認証ユーザー（削除は本人のみ） |
| storage (post-images) | 全員 | 認証ユーザー |

---

## よくある質問

**Q: ロールアップとして投票できますか？**  
A: ログイン不要で投票できます（localStorage でトラッキング）。ログイン時は Supabase に永続化されます。

**Q: 画像のアップロードサイズ上限は？**  
A: クライアント側で 10MB に制限しています。Supabase Storage の無料枠は 1GB です。

**Q: 殿堂入りはどうやって設定する？**  
A: Supabase Dashboard の Table Editor で該当投稿の `is_hof` を `true` に変更してください。

**Q: モデレーションは？**  
A: 現状はクリエイター本人のみが投稿できます（X OAuth 必須）。不適切な投稿は Supabase Dashboard から削除できます。

---

## ライセンス

MIT License — 自由に改変・再配布してください。

---

*供養アーカイブ — 没になった設定に、新しい命を。*
