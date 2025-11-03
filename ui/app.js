(function(){
  const $ = (id) => document.getElementById(id);
  const log = (msg) => { $('log').textContent += msg + "\n"; };

  function apiBase() {
    const b = (window.API_BASE || "").replace(/\/+$/,''); 
    if(!b){ log("WARNING: API_BASE not set in env.js"); }
    return b;
  }

  async function sign(path) {
    const res = await fetch(apiBase() + path);
    if (!res.ok) throw new Error(path + " failed: " + res.status);
    return res.json();
  }

  $('btn-upload').onclick = async () => {
    const fileInput = $('fileInput');
    const voice = ($('voice').value || "Joanna").trim();
    
    let name, body, contentType;
    
    if (fileInput.files.length > 0) {
      // File upload mode
      const file = fileInput.files[0];
      name = file.name;
      body = file;
      contentType = file.type || "application/octet-stream";
      log("Uploading file: " + name);
    } else {
      // Text input mode
      name = ($('fname').value || "story.txt").trim();
      const text = $('text').value;
      if (!text) { alert("Please enter some text or select a file"); return; }
      if (!name.endsWith(".txt")) { alert("Filename must end with .txt"); return; }
      body = new Blob([text], {type: "text/plain"});
      contentType = "text/plain";
    }
    
    const supportedExts = [".txt", ".pdf", ".docx", ".doc"];
    const hasValidExt = supportedExts.some(ext => name.toLowerCase().endsWith(ext));
    if (!hasValidExt) {
      alert("File must be .txt, .pdf, .docx, or .doc");
      return;
    }

    try {
      $('log').textContent = "";
      log("Requesting presigned PUT for input/" + name + "...");
      const s = await sign("/sign-put?key=" + encodeURIComponent("input/" + name));

      log("Uploading via presigned URL...");
      const put = await fetch(s.put_url, {
        method: "PUT",
        headers: { "Content-Type": contentType, "x-amz-meta-voice": voice },
        body: body
      });
      if (!put.ok) throw new Error("Upload failed: " + put.status);

      log("Uploaded. Expected output: " + s.expected_output);
      log("Click 'Refresh Play Link' in ~30-60s to try playback.");
    } catch (e) {
      log("ERROR: " + e.message);
    }
  };

  $('btn-refresh-link').onclick = async () => {
    const fileInput = $('fileInput');
    let filename;
    
    if (fileInput.files.length > 0) {
      filename = fileInput.files[0].name;
    } else {
      filename = ($('fname').value || "story.txt").trim();
    }
    
    const base = filename.replace(/\.[^.]+$/, ""); // Remove any extension
    const outKey = "output/" + base + ".mp3";
    try {
      log("Requesting a temporary GET link for " + outKey + "...");
      const s = await sign("/sign-get?key=" + encodeURIComponent(outKey));
      $('player').src = s.get_url;
      log("If processing is complete, the audio will play below.");
    } catch (e) {
      log("ERROR: " + e.message + " (Audio may not be ready yet)");
    }
  };
})();