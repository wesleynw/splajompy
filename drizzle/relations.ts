import { relations } from "drizzle-orm/relations";
import { users, follows, posts, likes, images, notifications, comments } from "./schema";

export const followsRelations = relations(follows, ({one}) => ({
	user_followerId: one(users, {
		fields: [follows.followerId],
		references: [users.userId],
		relationName: "follows_followerId_users_userId"
	}),
	user_followingId: one(users, {
		fields: [follows.followingId],
		references: [users.userId],
		relationName: "follows_followingId_users_userId"
	}),
}));

export const usersRelations = relations(users, ({many}) => ({
	follows_followerId: many(follows, {
		relationName: "follows_followerId_users_userId"
	}),
	follows_followingId: many(follows, {
		relationName: "follows_followingId_users_userId"
	}),
	posts: many(posts),
	likes: many(likes),
	notifications: many(notifications),
	comments: many(comments),
}));

export const postsRelations = relations(posts, ({one, many}) => ({
	user: one(users, {
		fields: [posts.userId],
		references: [users.userId]
	}),
	likes: many(likes),
	images: many(images),
	comments: many(comments),
}));

export const likesRelations = relations(likes, ({one}) => ({
	post: one(posts, {
		fields: [likes.postId],
		references: [posts.postId]
	}),
	user: one(users, {
		fields: [likes.userId],
		references: [users.userId]
	}),
}));

export const imagesRelations = relations(images, ({one}) => ({
	post: one(posts, {
		fields: [images.postId],
		references: [posts.postId]
	}),
}));

export const notificationsRelations = relations(notifications, ({one}) => ({
	user: one(users, {
		fields: [notifications.userId],
		references: [users.userId]
	}),
}));

export const commentsRelations = relations(comments, ({one}) => ({
	post: one(posts, {
		fields: [comments.postId],
		references: [posts.postId]
	}),
	user: one(users, {
		fields: [comments.userId],
		references: [users.userId]
	}),
}));