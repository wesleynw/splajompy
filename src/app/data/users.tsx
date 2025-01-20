"use client";

import { useQuery } from "@tanstack/react-query";
import { getAllUsers } from "../lib/users";

export function useUsers() {
  const { isPending, isError, data, error } = useQuery({
    queryKey: ["all-users"],
    queryFn: getAllUsers,
  });

  return { isPending, isError, users: data, error };
}
