# Publishing Checklist

Use this checklist before pushing Unifer to GitHub or preparing a release.

## 1. Sanity Check the Repo

- Confirm the app starts with `swift run Unifer`
- Confirm the app bundle builds with `./scripts/build_app.sh release`
- Smoke test:
  - clipboard capture
  - search
  - folder rename/color
  - image preview
  - paste via `Return`

## 2. Clean Repository Contents

Do not commit:

- `.build/`
- local SQLite databases
- generated `.app` bundles
- Android local SDK files

Current `.gitignore` already covers most generated files. If you keep local release artifacts, prefer storing them under `dist/`.

## 3. Recommended GitHub Repo Setup

- Repository name: `unifer`
- Short description: `A native macOS clipboard manager with shelf UI, folders, search, and quick paste.`
- Topics:
  - `macos`
  - `swift`
  - `swiftui`
  - `appkit`
  - `clipboard-manager`
  - `productivity`

## 4. First Public README Expectations

Make sure the root `README.md` answers:

- what the project is
- what works today
- how to run it locally
- how to build the `.app`
- what permissions macOS may request

## 5. Add a License

If you plan to publish publicly, add a license before opening the repository.

Common choices:

- `MIT` for maximum reuse
- `Apache-2.0` for reuse plus patent grant
- `GPL-3.0` if you want derivative works to remain open

## 6. Create a First Release Build

Suggested flow:

```bash
./scripts/build_app.sh release
open dist/Unifer.app
```

Then optionally sign it:

```bash
codesign --force --deep --sign "Developer ID Application: Your Name" dist/Unifer.app
```

For distribution outside your machine, notarization is the next step after signing.

## 7. Good First GitHub Milestones

- Add app icon and bundle metadata polish
- Convert Swift package executable into a full Xcode app target if needed
- Add CI build checks
- Add signed release artifacts
- Add onboarding screenshots / GIFs to `README.md`

## 8. Suggested Initial Commit Groups

- `feat: initial macOS clipboard manager`
- `feat: add folders, search, and paste flow`
- `docs: add build and publishing guide`
