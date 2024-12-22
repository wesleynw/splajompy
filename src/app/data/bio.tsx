import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getUserBio, setUserBio } from "../lib/users";

export function useBio(user_id: number) {
  const queryClient = useQueryClient();

  const { isPending, isError, data, error } = useQuery({
    queryKey: ["bio", user_id],
    queryFn: () => getUserBio(user_id),
  });

  const mutation = useMutation({
    mutationFn: (bio: string) => {
      return setUserBio(user_id, bio);
    },
    onMutate: async (bio: string) => {
      await queryClient.cancelQueries({ queryKey: ["bio", user_id] });
      const previousBio = queryClient.getQueryData(["bio", user_id]);
      console.log("optimistic update bio: ", bio);
      queryClient.setQueryData(["bio", user_id], bio);
      return previousBio;
    },
    onSettled: async () => {
      return await queryClient.invalidateQueries({
        queryKey: ["bio", user_id],
      });
    },
    onError: (context: { previousBio: string }) => {
      queryClient.setQueryData(["bio", user_id], context.previousBio);
    },
  });

  return {
    isPending,
    isError,
    data,
    error,
    mutation,
  };
}
