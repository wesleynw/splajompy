This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

## Features

- My own auth system, which includes OTP logins.

## Playright

To run Playwright tests:

```
pnpm exec playwright test
```

For visual mode, append `--ui`.

## Database Migrations

Drizzle-Kit provides a helpful command to apply migrations to databases [here](https://orm.drizzle.team/docs/migrations).

Since there's no development branch, and our preview environments share a development branch (to work nicely with Playwright), there's no easy way to automatically apply migrations. Should a database change need to be made, it should first be tested:

1. Use Neon to create a database branch.
2. Update local `.env` to match connection strings
3. Make schema changes, then generate and apply database migrations

   > `npx drizzle-kit generate`

   > `npx drizzle-kit migrate`

4. Test
5. Playwright will fail during PR checks because schema changes have not been made to the development database. If no other PRs are open, migrate the development DB.
6. Migrate the main database when the PR is merged
