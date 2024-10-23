import styles from "./page.module.css";
import { auth } from "@/auth";
import { SignOut } from "./components/signout-button";
import Link from "next/link";
import NewPost from "./components/NewPost";
import { redirect } from "next/navigation";
import Feed from "./components/Feed";

export default async function Home() {
  const session = await auth();

  if (!session) {
    redirect("/login");
  }

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <h1>Home</h1>
        <NewPost />
        <Feed />
      </main>
      <footer className={styles.footer}>
        {session ? (
          <div>
            <p>you are logged as</p>
            <p>
              <b>{session.user?.email}</b>
            </p>
            <SignOut />
          </div>
        ) : (
          <div>
            <p>you are not signed in</p>
            <Link href="login">sign in</Link>
          </div>
        )}
      </footer>
    </div>
  );
}
