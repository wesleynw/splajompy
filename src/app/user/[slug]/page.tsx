import UserView from "@/app/components/user/UserView";
import Navigation from "@/app/components/navigation/Navigation";
import { getUserByUsername } from "@/app/lib/users";
import { auth } from "@/auth";
import { SessionProvider } from "next-auth/react";
import { redirect } from "next/navigation";
import { Box, Typography } from "@mui/material";

export async function generateMetadata(props: {
  params: Promise<{ slug: string }>;
}) {
  const params = await props.params;
  return {
    title: `${params.slug}'s Profile`,
  };
}

export default async function Page({
  params,
}: Readonly<{
  params: Promise<{ slug: string }>;
}>) {
  const slug = (await params).slug;
  const username = String(slug);

  const session = await auth();

  if (!session) {
    redirect("/login");
  }

  const user = await getUserByUsername(username);

  if (!user) {
    return (
      <Box
        maxWidth="600px"
        display="flex"
        flexDirection="column"
        alignItems="center"
        sx={{ margin: "0 auto", padding: 4 }}
      >
        <Typography
          variant="h6"
          sx={{
            textAlign: "center",
            color: "#777777",
            paddingBottom: 2,
          }}
        >
          This user doesn&apos;t exist.
        </Typography>
      </Box>
    );
  }

  return (
    <SessionProvider session={session}>
      <Box
        sx={{
          width: "100%",
          maxWidth: { xs: "100%", md: "600" },
          margin: "auto",
          boxSizing: "border-box",
          paddingBottom: 20,
        }}
      >
        <UserView user={user} />
      </Box>
      <Navigation session={session} />
    </SessionProvider>
  );
}
