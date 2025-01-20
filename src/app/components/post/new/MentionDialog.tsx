import { useUsers } from "@/app/data/users";
import { Box, Divider, List, ListItemButton } from "@mui/material";
import { RichTextareaHandle } from "rich-textarea";

type Props = {
  mentionedUser: string;
  setTextValue: React.Dispatch<React.SetStateAction<string>>;
  setMentionDialogOpen: React.Dispatch<React.SetStateAction<boolean>>;
  inputRef: React.RefObject<RichTextareaHandle | null>;
};

export default function MentionDialog({
  mentionedUser,
  setTextValue,
  setMentionDialogOpen,
  inputRef,
}: Readonly<Props>) {
  const { isPending, users } = useUsers();

  function mentionToSpecialFormat(id: number, username: string) {
    const tag = `{tag:${id}:${username}}`;
    setTextValue((prev: string) => {
      const regex = new RegExp(`@${mentionedUser}(.*?)(?=@|$)`, "g");
      return prev.replace(regex, tag);
    });
  }

  return (
    <Box sx={{ zIndex: "100" }}>
      <List
        dense={true}
        sx={{
          position: "fixed",
          backgroundColor: "black",
          borderRadius: "10px",
          border: "1px solid white",
        }}
      >
        {users && users.length > 0 && !isPending ? (
          (() => {
            const filteredUsers = users.filter((user) =>
              user.username.startsWith(mentionedUser)
            );
            return filteredUsers.length > 0 ? (
              filteredUsers.slice(0, 5).map((user, index) => (
                <div key={user.user_id}>
                  <ListItemButton
                    disableRipple
                    onClick={() => {
                      mentionToSpecialFormat(user.user_id, user.username);
                      setMentionDialogOpen(false);
                      inputRef.current?.focus();
                    }}
                  >
                    {user.username}
                  </ListItemButton>
                  {index < 5 && (
                    <Divider sx={{ color: "gray", border: "1px solid" }} />
                  )}
                </div>
              ))
            ) : (
              <ListItemButton>
                <h3>No users found</h3>
              </ListItemButton>
            );
          })()
        ) : (
          <ListItemButton>...</ListItemButton>
        )}
      </List>
    </Box>
  );
}
