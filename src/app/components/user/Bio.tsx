import { useBio } from "@/app/data/bio";
import { Button, Stack, Typography } from "@mui/material";
import { useState } from "react";

type Props = {
  isOwnProfile: boolean;
  user: {
    user_id: number;
    email: string;
    password: string;
    username: string;
  };
};

export default function Bio({ isOwnProfile, user }: Readonly<Props>) {
  const [isEditing, setIsEditing] = useState(false);
  const { isPending, data, mutation } = useBio(user.user_id);

  if (isPending) {
    return <div>Loading...</div>;
  }

  return (
    <Stack
      direction="column"
      display="flex"
      alignItems="flex-start"
      spacing={1}
    >
      {isEditing ? (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            e.stopPropagation();
            const formData = new FormData(e.target as HTMLFormElement);
            const bio = formData.get("bio") as string;
            setIsEditing(false);
            mutation.mutate(bio);
          }}
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-start",
            margin: "2px",
          }}
        >
          <input type="text" name="bio" defaultValue={data?.bio} />
          <Button
            type="submit"
            size="medium"
            disabled={isPending}
            variant="contained"
            sx={{
              backgroundColor: "#1DA1F2",
              borderRadius: "20px",
              color: "#ffffff",
              padding: "1px",
            }}
          >
            {isEditing ? "Save" : "Add bio"}
          </Button>
        </form>
      ) : (
        <Typography>{data?.bio}</Typography>
      )}
      {isOwnProfile && !isEditing && (
        <Button
          onClick={() => setIsEditing(true)}
          size="medium"
          disabled={isPending}
          variant="contained"
          sx={{
            backgroundColor: "#1DA1F2",
            borderRadius: "20px",
            color: "#ffffff",
            padding: "1px",
          }}
        >
          {data ? "Edit bio" : "Add bio"}
        </Button>
      )}
    </Stack>
  );
}
