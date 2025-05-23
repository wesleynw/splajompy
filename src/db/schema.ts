import { sql } from "drizzle-orm";
import {
  boolean,
  integer,
  pgTable,
  serial,
  text,
  timestamp,
  unique,
  varchar,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  user_id: serial().primaryKey().notNull().unique(),
  name: text(),
  email: varchar({ length: 255 }).notNull().unique(),
  password: varchar({ length: 255 }).notNull(),
  username: varchar({ length: 100 }).notNull(),
  created_at: timestamp({ mode: "date" })
    .default(sql`CURRENT_TIMESTAMP`)
    .notNull(),
});

export type SelectUser = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

export type User = typeof users.$inferSelect;
export type PublicUser = Omit<User, "password">;

export const bios = pgTable("bios", {
  id: serial().primaryKey().notNull(),
  user_id: integer()
    .unique()
    .notNull()
    .references(() => users.user_id, { onDelete: "cascade" }),
  text: text().notNull(),
});

export const sessions = pgTable("sessions", {
  id: text().primaryKey(),
  user_id: integer()
    .notNull()
    .references(() => users.user_id),
  expires_at: timestamp({ withTimezone: true, mode: "date" }).notNull(),
});

export type Session = typeof sessions.$inferSelect;

export const verificationCodes = pgTable("verificationCodes", {
  id: serial().primaryKey().notNull(),
  code: text().notNull(),
  user_id: integer()
    .unique()
    .notNull()
    .references(() => users.user_id, { onDelete: "cascade" }),
  expires_at: timestamp({ mode: "date" }).notNull(),
});

export const posts = pgTable("posts", {
  post_id: serial().primaryKey().notNull(),
  user_id: integer("user_id")
    .notNull()
    .references(() => users.user_id, {
      onDelete: "cascade",
    }),
  text: text(),
  created_at: timestamp({ mode: "string" })
    .default(sql`CURRENT_TIMESTAMP`)
    .notNull(),
});

export type SelectPost = typeof posts.$inferSelect;
export type InsertPost = typeof posts.$inferInsert;

export const comments = pgTable("comments", {
  comment_id: serial().primaryKey().notNull(),
  post_id: integer("post_id")
    .notNull()
    .references(() => posts.post_id, {
      onDelete: "cascade",
    }),
  user_id: integer("user_id")
    .notNull()
    .references(() => users.user_id, {
      onDelete: "cascade",
    }),
  text: text().notNull(),
  created_at: timestamp({ mode: "string" })
    .default(sql`CURRENT_TIMESTAMP`)
    .notNull(),
});

export type Comment = typeof comments.$inferSelect;
export type InsertComment = typeof comments.$inferInsert;

export const images = pgTable("images", {
  image_id: serial().primaryKey().notNull(),
  post_id: integer("post_id")
    .notNull()
    .references(() => posts.post_id, { onDelete: "cascade" }),
  height: integer().notNull(),
  width: integer().notNull(),
  image_blob_url: text().notNull(),
  display_order: integer().default(0).notNull(),
});

export type ImageType = typeof images.$inferSelect;

export const follows = pgTable(
  "follows",
  {
    follower_id: integer("follower_id")
      .notNull()
      .references(() => users.user_id, { onDelete: "cascade" }),
    following_id: integer("following_id")
      .notNull()
      .references(() => users.user_id, {
        onDelete: "cascade",
      }),
    created_at: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [unique().on(table.follower_id, table.following_id)],
);

export const likes = pgTable(
  "likes",
  {
    post_id: integer("post_id")
      .notNull()
      .references(() => posts.post_id, { onDelete: "cascade" }),
    comment_id: integer("comment_id").references(() => comments.comment_id, {
      onDelete: "cascade",
    }),
    user_id: integer("user_id")
      .notNull()
      .references(() => users.user_id, { onDelete: "cascade" }),
    is_post: boolean().notNull().default(true),
    created_at: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    unique().on(table.user_id, table.post_id, table.comment_id, table.is_post),
  ],
);

export type Like = typeof likes.$inferSelect;

export const notifications = pgTable("notifications", {
  notification_id: serial().primaryKey().notNull(),
  user_id: integer("user_id")
    .notNull()
    .references(() => users.user_id, { onDelete: "cascade" }),
  post_id: integer("post_id").references(() => posts.post_id, {
    onDelete: "cascade",
  }),
  comment_id: integer("comment_id").references(() => comments.comment_id, {
    onDelete: "cascade",
  }),
  message: text().notNull(),
  link: text(),
  viewed: boolean().default(false),
  created_at: timestamp({ mode: "string" })
    .default(sql`CURRENT_TIMESTAMP`)
    .notNull(),
});

export type NotificationData = typeof notifications.$inferSelect;
