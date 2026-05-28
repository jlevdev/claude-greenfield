Prepare and execute a deployment.

## First-time setup — REQUIRED
Deployment is highly project-specific. Before doing anything, check `CLAUDE.md` for a `## Deployment` section.

If that section does not exist, gather the following and document it in `CLAUDE.md` before proceeding:

1. **Platform/target:** Where does the project run?
   - Web: Vercel, Netlify, Fly.io, Railway, AWS, GCP, Azure, custom VPS, etc.
   - Mobile: App Store (iOS), Google Play (Android), both
   - Desktop: direct binary, Steam, Epic Games Store, itch.io
   - Game engine: Unreal packaged build, Unity build pipeline
   - Other: describe it

2. **Environments:** Is there a dev/staging/prod split? How do you promote between them?

3. **CI/CD pipeline?** Automatic on push/merge, or manual command?

4. **Pre-deploy steps:** build command, DB migrations, env var sync, asset upload, etc.

5. **Rollback plan:** How do you revert a bad deploy?

Document everything in `CLAUDE.md` under a `## Deployment` section. All future deploys will reference it.

## Universal pre-deploy checklist
Run through this before every deployment:
- [ ] All tests pass (run the test command from `CLAUDE.md`)
- [ ] No tickets remain in `tickets/*/in-progress/`
- [ ] No `.env` files or secrets committed
- [ ] All required environment variables are set in the target environment
- [ ] Version number bumped (if the project uses versioning)
- [ ] CHANGELOG updated (if applicable)
- [ ] Branch is up to date with base branch (no merge conflicts)

## Production deployments
**Always confirm with the user before deploying to production.** State the exact command you are about to run and wait for explicit approval.

## Platform-specific notes
*(filled in during `/start-project` or first `/deploy` run)*

These notes expand based on your project type:
- **Vercel / Netlify:** `vercel --prod` or `netlify deploy --prod`; check env vars in dashboard
- **Fly.io:** `fly deploy`; ensure `fly.toml` is current
- **Docker-based:** build image, push to registry, update service
- **Mobile (App Store / Google Play):** requires signing certs, provisioning profiles, and store review; plan for 1-3 day review time
- **Unreal Engine:** package the project via editor or UAT (`RunUAT.bat BuildCookRun ...`); ask about platform target (Windows/PS5/Xbox/etc.)
- **Steam:** upload via `steamcmd` or Steamworks partner portal; ask about depot config
