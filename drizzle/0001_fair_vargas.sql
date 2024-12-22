CREATE TABLE "bios" (
	"user_id" integer NOT NULL,
	"bio" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "bios" ADD CONSTRAINT "bios_user_id_users_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id") ON DELETE cascade ON UPDATE no action;