import FileUpload from "./FileUpload";
import { useState, useRef } from "react";

function App() {

  const [fileName, setFileName] = useState<string | null>(null);

  const imgContainerRef = useRef<HTMLDivElement>(null);

  const showImage = async (filename: string) => {
    const response = await fetch(`${import.meta.env.VITE_API_ENDPOINT}/file/${filename}`);

    const { signedUrl } = await response.json();

    if (imgContainerRef.current) {
      imgContainerRef.current.innerHTML = '';
    }
    const urlText = document.createElement('pre');
    urlText.style.overflow = 'scroll';
    urlText.textContent = `Image URL: ${signedUrl}`;
    imgContainerRef.current?.appendChild(urlText);

    const img = document.createElement('img');
    img.src = signedUrl;
    img.style.maxWidth = '300px';
    imgContainerRef.current?.appendChild(img);      
  }

  return (
    <>
      <FileUpload onSubmit={setFileName}/>
      {fileName && <button onClick={() => showImage(fileName)}>Show Image</button>}
      <div ref={imgContainerRef}/>
    </>
  )
}

export default App
