import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import sharp from "sharp";

async function streamToBuffer(stream: NodeJS.ReadableStream): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    stream.on("data", (chunk: Buffer) => chunks.push(chunk));
    stream.on("error", (err: Error) => reject(err));
    stream.on("end", () => resolve(Buffer.concat(chunks)));
  });
}

interface MainEvent {
  body: {
    objectKey: string;
  };
}

interface SuccessResponse {
  statusCode: number;
  body: string;
}

interface ErrorResponse {
  statusCode: number;
  body: string;
}

export async function main(
  event: MainEvent
): Promise<SuccessResponse | ErrorResponse> {
  const { objectKey } = event.body;

  const s3 = new S3Client({
    region: process.env.SPACES_REGION,
    endpoint: `https://${process.env.SPACES_REGION}.digitaloceanspaces.com`,
    credentials: {
      accessKeyId: process.env.SPACES_ACCESS_KEY!,
      secretAccessKey: process.env.SPACES_SECRET_KEY!,
    },
  });

  try {
    const getCommand = new GetObjectCommand({
      Bucket: process.env.SPACES_BUCKET!,
      Key: objectKey,
    });

    const getObjectResponse = await s3.send(getCommand);
    const originalImageBuffer = await streamToBuffer(
      getObjectResponse.Body as NodeJS.ReadableStream
    );

    const compressedImageBuffer = await sharp(originalImageBuffer)
      .rotate()
      .resize(1000, undefined, {
        withoutEnlargement: true,
        fit: "inside",
      })
      .jpeg({ quality: 80, force: true })
      .withMetadata({ orientation: 1 })
      .toBuffer();

    const putCommand = new PutObjectCommand({
      Bucket: process.env.SPACES_BUCKET!,
      Key: objectKey,
      Body: compressedImageBuffer,
      ACL: "public-read",
      ContentType: `image/jpeg`,
    });
    await s3.send(putCommand);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Successfully compressed image",
        objectKey,
      }),
    };
  } catch (err) {
    if (err instanceof Error) {
      console.error(err);
      return {
        statusCode: 500,
        body: JSON.stringify({ error: err.message }),
      };
    } else {
      console.error("Unknown error", err);
      return {
        statusCode: 500,
        body: JSON.stringify({ error: "Unknown error" }),
      };
    }
  }
}
