import {
  pgTable,
  serial,
  varchar,
  integer,
  timestamp,
  text,
  unique,
  boolean,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const users = pgTable("users", {
  user_id: serial().primaryKey().notNull().unique(),
  email: varchar({ length: 255 }).notNull().unique(),
  password: varchar({ length: 255 }).notNull(),
  username: varchar({ length: 100 }).notNull(),
});

export const bios = pgTable("bios", {
  user_id: integer("user_id")
    .primaryKey()
    .notNull()
    .references(() => users.user_id, { onDelete: "cascade" }),
  bio: text().notNull(),
});

export type SelectUser = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

export const posts = pgTable("posts", {
  post_id: serial().primaryKey().notNull(),
  user_id: integer("user_id")
    .notNull()
    .references(() => users.user_id, {
      onDelete: "cascade",
    }),
  text: text(),
  postdate: timestamp({ mode: "string" })
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
  comment_date: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
});

export type SelectComment = typeof comments.$inferSelect;
export type InsertComment = typeof comments.$inferInsert;

export const images = pgTable("images", {
  image_id: serial().primaryKey().notNull(),
  post_id: integer("post_id")
    .notNull()
    .references(() => posts.post_id, { onDelete: "cascade" }),
  height: integer().notNull(),
  width: integer().notNull(),
  imageBlobUrl: text().notNull(),
});

export type SelectImage = typeof images.$inferSelect;

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
  (table) => [unique().on(table.follower_id, table.following_id)]
);

export const likes = pgTable(
  "likes",
  {
    post_id: integer("post_id")
      .notNull()
      .references(() => posts.post_id, { onDelete: "cascade" }),
    user_id: integer("user_id")
      .notNull()
      .references(() => users.user_id, { onDelete: "cascade" }),
    created_at: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [unique().on(table.post_id, table.user_id)]
);

export const notifications = pgTable("notifications", {
  notification_id: serial().primaryKey().notNull(),
  user_id: integer("user_id")
    .notNull()
    .references(() => users.user_id, { onDelete: "cascade" }),
  message: text().notNull(),
  link: text(),
  viewed: boolean().default(false),
  created_at: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
});

export type SelectNotification = typeof notifications.$inferSelect;
