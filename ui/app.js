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
    const name = ($('fname').value || "story.txt").trim();
    const voice = ($('voice').value || "Joanna").trim();
    const text = $('text').value;
    if (!text) { alert("Please enter some text"); return; }
    if (!name.endsWith(".txt")) { alert("Filename must end with .txt"); return; }

    try {
      $('log').textContent = "";
      log("Requesting presigned PUT for input/" + name + "...");
      const s = await sign("/sign-put?key=" + encodeURIComponent("input/" + name));

      log("Uploading plain text via presigned URL...");
      const put = await fetch(s.put_url, {
        method: "PUT",
        headers: { "Content-Type": "text/plain", "x-amz-meta-voice": voice },
        body: new Blob([text], {type: "text/plain"})
      });
      if (!put.ok) throw new Error("Upload failed: " + put.status);

      log("Uploaded. Expected output: " + s.expected_output);
      log("Click 'Refresh Play Link' in ~30-60s to try playback.");
    } catch (e) {
      log("ERROR: " + e.message);
    }
  };

  $('btn-refresh-link').onclick = async () => {
    const base = ($('fname').value || "story.txt").trim().replace(/\.txt$/,"");
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