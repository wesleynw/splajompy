import {
  pgTable,
  serial,
  varchar,
  integer,
  text,
  timestamp,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const users = pgTable("users", {
  user_id: serial().primaryKey().notNull().unique(),
  email: varchar({ length: 255 }).notNull().unique(),
  password: varchar({ length: 255 }).notNull(),
  username: varchar({ length: 100 }).notNull(),
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
  text: text().notNull(),
  link: text(),
  postdate: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
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
  text: varchar({ length: 255 }).notNull(),
  comment_date: timestamp({ mode: "string" }).default(sql`CURRENT_TIMESTAMP`),
});

export type SelectComment = typeof comments.$inferSelect;
export type InsertComment = typeof comments.$inferInsert;
