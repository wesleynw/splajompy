import { deleteSessionTokenCookie } from "@/app/auth/cookies";
import { getCurrentSession, invalidateSession } from "@/app/auth/session";
import { PublicUser } from "@/db/schema";
import { redirect } from "next/navigation";
import FollowButton from "../follows/FollowButton";

type Props = {
  user: PublicUser;
  isOwnProfile: boolean;
};

export default function UserProfile({ user, isOwnProfile }: Readonly<Props>) {
  const handleSignOut = async () => {
    const { session } = await getCurrentSession();
    if (session !== null) {
      invalidateSession(session.id);
      deleteSessionTokenCookie();
      redirect("/login");
    }
  };

  return (
    <div className="flex w-full flex-row justify-between border-t-1 border-neutral-800 p-4 sm:border-x-1">
      <p className="ml-1 text-lg font-black">@{user.username}</p>
      {isOwnProfile && (
        <button
          className="rounded-full bg-blue-400 px-2.5 py-1 font-bold"
          onClick={handleSignOut}
        >
          Sign Out
        </button>
      )}
      <FollowButton user_id={user.user_id} show_unfollow={true} />
    </div>
  );
}
