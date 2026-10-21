# PIA Social

Source setup instructions. Public-history credential and user-data remediation is still pending; the complete local backup is verified, but the latest source has not yet been pushed or verified from GitHub.

PIA Social is a Python/Flask web application with a Capacitor iOS shell. The repository also includes Android source and a separate `pokestock-intel` application. Keep these existing folders unless a deliberate project split is planned.

Repository: https://github.com/OGPancakes/MEDIA — public by the owner's choice. Never commit passwords, signing keys, local databases, user uploads, or private account lists.

## What goes between computers

GitHub synchronizes committed source code, assets, dependency manifests, and shared project settings. It does not synchronize uncommitted edits, local databases, user uploads, secrets, installed dependencies, or Codex chat history. Keep a separate private backup of important local data.

Use a separate local clone on each computer. Do not use iCloud or OneDrive to synchronize a working Git folder between computers.

## Windows setup: easiest option

1. Install [Git for Windows](https://git-scm.com/downloads/win), [GitHub Desktop](https://desktop.github.com/), and [VS Code](https://code.visualstudio.com/). Cursor can also edit the same folder.
2. Open GitHub Desktop and sign in to your GitHub account through its browser sign-in flow. Never paste an access token into the repository URL.
3. Choose **File → Clone repository → URL** and enter `https://github.com/OGPancakes/MEDIA.git`.
4. Use a local folder such as `C:\Users\YOURNAME\source\MEDIA`. Avoid OneDrive-backed Documents/Desktop folders.
5. Choose **Open in Visual Studio Code**, or use your editor's **Open Folder** command and select `MEDIA`.
6. In Codex, add/open that same `MEDIA` folder as a local project. Ask it to inspect Git status before changing files and to review staged files before committing. The editor and Codex can use the same files; avoid having both make overlapping edits at once.
7. To test the web application, also install a supported Python 3 version. Install Node.js LTS if working with Capacitor or `pokestock-intel`.

**Windows limitation:** Windows can edit and version-control Swift, HTML, CSS, JavaScript, Python, and Xcode project files. Native Xcode builds, iOS signing, and Apple's iOS Simulator require a Mac or suitable remote Mac infrastructure. Test the iOS app on the Mac before shipping.

## Windows setup: command-line alternative

Open PowerShell after installing Git:

```powershell
New-Item -ItemType Directory -Force "$HOME\source"
Set-Location "$HOME\source"
git clone https://github.com/OGPancakes/MEDIA.git
Set-Location MEDIA
git config pull.ff only
```

Set your commit name and email using GitHub Desktop or `git config user.name` and `git config user.email`. An account-linked GitHub noreply email can keep your personal address out of new commits. A public repository can be cloned without signing in; pushing requires your authorized GitHub account. Git for Windows normally opens a browser sign-in when authentication is needed. Do not enter your GitHub account password as a Git HTTPS password.

## Mac setup

The existing working project is `/Users/gabethomas/Documents/MEDIA`. Do not clone over it or replace it with another computer's copy.

For a genuinely new Mac checkout, use a local development folder outside cloud-synchronized Documents, then clone the same URL. Do not move the existing working folder until its full backup and recovery checks are complete.

Install Xcode, Git, Node.js LTS compatible with Capacitor 7, and CocoaPods. In the project folder:

```sh
npm ci
npm run cap:sync -- ios
open ios/App/App.xcworkspace
```

`npm ci` recreates dependencies from `package-lock.json`. Capacitor sync recreates copied web assets and native dependency integration. Open the workspace, select the App scheme, choose an installed iPhone Simulator, and use Run. For a physical device, select your own development team in Signing & Capabilities. Keep certificates, provisioning credentials, and APNs private keys outside Git.

Keep `ios/App/Podfile`, `ios/App/Podfile.lock`, the workspace, project file, Swift source, entitlements, storyboards, and asset catalogs in Git. CocoaPods and build output can be recreated. Inspect unexpected lockfile changes before committing them.

The iOS shell currently loads the configured Railway website by default. Changing Python or server templates locally does not change the deployed website automatically. `CAP_SERVER_URL` selects a different backend when regenerating Capacitor configuration. Do not point a development build at production for write tests.

## Optional local web development

Use a new, disposable development database. Do not copy real accounts or messages into Git or another public location.

Mac, from the repository root:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

Windows PowerShell:

```powershell
py -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe app.py
```

Fresh development databases do not receive a default administrator password. Existing accounts keep their passwords across restarts. For a new administrator, privately configure `PIA_INITIAL_ADMIN_PASSWORD` and optionally `PIA_INITIAL_ADMIN_EMAIL` before the first start. Remove the bootstrap password from the environment after the account exists.

The app creates its SQLite database and a private `.secret_key` in `DATA_DIR`, which defaults to the project root. `.secret_key` must stay private and untracked. `.env` files are not automatically loaded by this Flask application; configure environment variables in your terminal or deployment service. Do not copy a production secret into documentation.

APNs needs locally configured `APNS_KEY_ID`, `APNS_TEAM_ID`, and either `APNS_AUTH_KEY_PATH` or `APNS_AUTH_KEY`, plus the bundle/environment settings. Obtain private signing material through an authorized private channel. GitHub should not contain the private key.

`pokestock-intel` has its own README, package lock, and `.env.example`. Follow those instructions only when working on that application. Browser-facing `VITE_` values are visible to the browser; never place server secrets there.

## Daily workflow

Start in the repository folder:

```sh
git status
git pull --ff-only
```

`git status` shows local changes. `git pull --ff-only` downloads the latest source and updates your branch only when Git can do so without creating a merge. Stop if it reports local changes, divergence, or an error. Resolve those deliberately; do not force synchronization.

After editing and testing:

```sh
git status
git diff
git add -- app.py
git diff --cached
git commit -m "Describe the change"
git push
git status
```

`git add -- app.py` is an example: stage each source file you actually intend to publish, or select the files in GitHub Desktop. `git diff --cached` reviews exactly what will be committed. `git commit` saves a local checkpoint. `git push` uploads committed changes to GitHub. A commit alone is not a cloud backup. Check that the push succeeds and that Git reports your branch up to date.

Avoid staging everything blindly. Ignoring a file does not remove an already tracked file or its older history. Never stage secrets, real databases, private user media, account lists, caches, or build output.

## Switching computers

1. On computer A, inspect changes, test what you can, commit appropriate source, and push.
2. Confirm the push succeeded. If important work is still uncommitted or unpushed, it is not available on computer B through GitHub.
3. On computer B, open its local `MEDIA` clone, check status, and pull before editing.
4. Edit, test, commit, and push there.
5. Back on the Mac, check status and pull before opening the app for build/signing/testing.

With GitHub Desktop, the same cycle is **Fetch/Pull origin → edit → review selected changes → Commit → Push origin**.

## Conflicts and safety

If a conflict or diverged-history message appears, stop and inspect it. Do not blindly choose a whole side, overwrite files, discard changes, force-push, or run destructive reset/clean commands. Ask Codex to explain each conflicting section while preserving both versions for review.

## Daily cheat sheet

**Starting:** open folder → check status → pull → edit → test.

**Finishing:** review changes → stage appropriate files → commit → push → confirm success.

**Switching:** push on A → verify → open B → pull before editing.

Official Codex/Windows guidance: https://learn.chatgpt.com/docs/windows/windows-app
