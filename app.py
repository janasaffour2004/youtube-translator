import streamlit as st
import os
import subprocess
import whisper
import uuid
import asyncio
import edge_tts
from deep_translator import GoogleTranslator

st.set_page_config(page_title="YouTube Translator", layout="centered")
st.title("🎥🔁 Translate YouTube Video to Another Language with Realistic Voice")

lang_option = st.selectbox("🌐 Select translation language:", ["English", "Arabic"])
target_lang = "en" if lang_option == "English" else "ar"
tts_voice = "en-US-JennyNeural" if target_lang == "en" else "ar-EG-SalmaNeural"

url = st.text_input("🔗 Enter YouTube video link (in Hindi):")

if url:
    video_id = str(uuid.uuid4())
    video_file = f"{video_id}.mp4"
    audio_file = f"{video_id}.wav"
    edge_audio_mp3 = f"{video_id}_edge.mp3"
    final_audio = f"{video_id}_final.aac"
    final_video = f"{video_id}_final.mp4"

    with st.spinner("📥 Downloading video..."):
        subprocess.run([
            "yt-dlp", "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4",
            "-o", video_file, url
        ], check=True)

    with st.spinner("🎧 Extracting audio..."):
        subprocess.run([
            "ffmpeg", "-y", "-i", video_file,
            "-q:a", "0", "-map", "a", audio_file
        ], check=True)

    with st.spinner("🧠 Translating from Whisper..."):
        model = whisper.load_model("base")
        result = model.transcribe(audio_file, language="hi", task="translate")
        translated_text = result["text"]

        if target_lang == "ar":
            st.info("🔁 Translating text to Arabic...")

            def split_text(text, max_len=5000):
                lines = text.split(". ")
                chunks, current = [], ""
                for line in lines:
                    if len(current) + len(line) + 1 < max_len:
                        current += line + ". "
                    else:
                        chunks.append(current.strip())
                        current = line + ". "
                chunks.append(current.strip())
                return chunks

            chunks = split_text(translated_text)
            translated_chunks = [
                GoogleTranslator(source='auto', target='ar').translate(chunk)
                for chunk in chunks
            ]
            translated_text = " ".join(translated_chunks)

    st.success("✅ Translation complete!")
    st.markdown("**📄 Final Translated Text:**")
    st.write(translated_text)

    async def generate_edge_tts(text, out_file, voice):
        communicate = edge_tts.Communicate(text, voice=voice)
        await communicate.save(out_file)

    with st.spinner("🔊 Generating realistic voice..."):
        asyncio.run(generate_edge_tts(translated_text, edge_audio_mp3, tts_voice))
        subprocess.run([
            "ffmpeg", "-y", "-i", edge_audio_mp3, "-c:a", "aac", final_audio
        ], check=True)

    with st.spinner("🎬 Merging voice with video..."):
        subprocess.run([
            "ffmpeg", "-y", "-i", video_file, "-i", final_audio,
            "-c:v", "copy", "-map", "0:v:0", "-map", "1:a:0", "-shortest",
            final_video
        ], check=True)

    st.success("🎉 Final video is ready!")
    st.video(final_video)

    with open(final_video, "rb") as f:
        st.download_button("⬇️ Download Video", f, file_name="translated_video.mp4")

    # تنظيف الملفات المؤقتة
    for f in [video_file, audio_file, edge_audio_mp3, final_audio]:
        if os.path.exists(f):
            os.remove(f)
