import { Box, useTheme } from "@mui/material";
import AddPhotoAlternateIcon from "@mui/icons-material/AddPhotoAlternate";

interface FileInputProps {
  file: File | null;
  setFile: (file: File | null) => void;
  setPreviewFile: (file: File | null) => void;
  setError: (error: string | null) => void;
}

export default function FileInput({
  file,
  setFile,
  setPreviewFile,
  setError,
}: Readonly<FileInputProps>) {
  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files ? event.target.files[0] : null;
    const maxSizeInBytes = 20 * 1024 * 1024;

    if (file) {
      if (file.size > maxSizeInBytes) {
        setError("File size must not exceed 20MB.");
        setFile(null);
        setPreviewFile(null);
        return;
      } else {
        setError(null);
      }

      setFile(file);
      setPreviewFile(file);
    }
  };

  const theme = useTheme();

  return (
    <Box sx={{ width: "100%", position: "relative" }}>
      <input
        type="file"
        onChange={handleFileSelect}
        style={{ display: "none" }}
        id="file-upload"
      />
      <label htmlFor="file-upload" style={{ cursor: "pointer" }}>
        <AddPhotoAlternateIcon
          fontSize="medium"
          sx={{
            marginLeft: "20px",
            color: "#777777",
            ...theme.applyStyles("dark", { color: "#b0b0b0" }),
          }}
          visibility={file ? "hidden" : "visible"}
        />
      </label>
    </Box>
  );
}
