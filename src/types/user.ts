export interface User {
  username: string;
  email: string;
}

export interface UserWithPassword extends User {
  password: string;
}
