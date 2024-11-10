"use server";

import ogs from "open-graph-scraper";

export default async function LinkPreviewFetcher(url: string | null) {
  if (!url) {
    return null;
  }

  try {
    const { result, error } = await ogs({ url });

    if (error) {
      console.error("Error fetching Open Graph data:", error);
      return null;
    }

    return result;
  } catch (error) {
    console.error("Unexpected error:", error);
    return null;
  }
}
