"use client";

export async function invokeCompressionFunction(user_id: number, key: string) {
  const function_url = process.env.NEXT_PUBLIC_SPACES_COMPRESSION_FN_URL!;

  console.log("object key: ", key);

  try {
    await new Promise((resolve) => setTimeout(resolve, 10000));
    const response = await fetch(function_url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        objectKey: key,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
  } catch (err) {
    console.error("Error invoking DigitalOcean function:", err);
  }
}
