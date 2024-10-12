import React, { useState } from "react";

interface FileUploadProps {
  onSubmit?: (filename: string) => void;
}

const FileUpload: React.FC<FileUploadProps> = ({ onSubmit }) => {
  const [file, setFile] = useState<File | null>(null);
  const [message, setMessage] = useState("");
  const [progress, setProgress] = useState(0);

  // Handle file selection
  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.files && event.target.files.length > 0) {
      setFile(event.target.files[0]);
    }
  };

  const handleFileSubmit = async () => {
    if (!file) {
      setMessage("Please select a file first.");
      return;
    }

    try {
      // Step 1: Request presigned URL from the backend
      const response = await fetch(`${import.meta.env.VITE_API_ENDPOINT}/file`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          filename: file.name,
          ftype: file.type,
        }),
      });

      const { signedUrl: url, fields } = await response.json();

      const formData = new FormData();
      Object.entries(fields).forEach(([key, value]) => {
        formData.append(key, value as string);
      });
      formData.append("file", file);

      const xhr = new XMLHttpRequest();
      xhr.open("POST", url); // Replace with your upload URL

      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable) {
          const percentComplete = (event.loaded / event.total) * 100;
          setProgress(percentComplete);
        }
      };

      xhr.onload = () => {
        if (xhr.status === 204) {
          setMessage("File uploaded successfully.");
          if (onSubmit) {
            onSubmit(file.name);
          }
        } else {
          setMessage("File upload failed.");
        }
        setProgress(0); // Reset progress
      };

      xhr.onerror = () => {
        setMessage("File upload failed.");
        setProgress(0); // Reset progress
      };

      xhr.send(formData);

    } catch (error) {
      console.error("File upload error:", error);
      setMessage("File upload failed. Please try again.");
    }
  };

  return (
    <div>
      <h1>File Upload with Presigned URL</h1>
      <input type="file" accept=".jpg,.jpeg,.png" onChange={handleFileChange} />
      <button onClick={handleFileSubmit}>Submit</button>
      {progress > 0 && (
        <div>
          <progress value={progress} max="100">{progress}%</progress>
        </div>
      )}
      <p>{message}</p>
    </div>
  );
};

export default FileUpload;
