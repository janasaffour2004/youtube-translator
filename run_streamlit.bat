import streamlit as st
import os
import subprocess
import whisper
import uuid
import asyncio
import edge_tts

# ========== إعداد ==========
st.set_page_config(page_title="YouTube Translator", layout="centered")
st.title("🎥🔁 ترجمة فيديو يوتيوب الهندي إلى الإنجليزية بصوت احترافي")

# ========== إدخال رابط يوتيوب ==========
url = st.text_input("🔗 أدخل رابط فيديو يوتيوب (بالهندية):")

if url:
    video_id = str(uuid.uuid4())
    video_file = f"{video_id}.mp4"
    audio_file = f"{video_id}.wav"
    english_audio_aac = f"{video_id}_en.aac"
    final_video = f"{video_id}_final.mp4"
    edge_audio_mp3 = f"{video_id}_edge.mp3"

    # ========== تحميل الفيديو ==========
    with st.spinner("📥 جاري تحميل الفيديو..."):
        ydl_cmd = [
            "yt-dlp",
            "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4",
            "-o", video_file,
            url
        ]
        subprocess.run(ydl_cmd, check=True)

    # ========== استخراج الصوت ==========
    with st.spinner("🎧 استخراج الصوت من الفيديو..."):
        ffmpeg_extract_cmd = [
            "ffmpeg", "-y", "-i", video_file,
            "-q:a", "0", "-map", "a",
            audio_file
        ]
        subprocess.run(ffmpeg_extract_cmd, check=True)

    # ========== الترجمة باستخدام Whisper ==========
    with st.spinner("🧠 الترجمة من الهندية إلى الإنجليزية..."):
        model = whisper.load_model("base")
        result = model.transcribe(audio_file, language="hi", task="translate")
        translated_text = result["text"]

    st.success("✅ الترجمة تمت!")
    st.markdown("**📄 النص المترجم:**")
    st.write(translated_text)

    # ========== تحويل النص إلى صوت احترافي باستخدام Edge TTS ==========
    async def generate_edge_tts(text, out_file, voice="en-US-JennyNeural"):
        communicate = edge_tts.Communicate(text, voice=voice)
        await communicate.save(out_file)

    with st.spinner("🔊 تحويل الترجمة إلى صوت واقعي..."):
        asyncio.run(generate_edge_tts(translated_text, edge_audio_mp3))

        # تحويل mp3 إلى aac
        convert_cmd = [
            "ffmpeg", "-y", "-i", edge_audio_mp3, "-c:a", "aac", english_audio_aac
        ]
        subprocess.run(convert_cmd, check=True)

    # ========== دمج الصوت الإنجليزي مع الفيديو ==========
    with st.spinner("🎬 دمج الصوت الإنجليزي مع الفيديو..."):
        ffmpeg_merge_cmd = [
            "ffmpeg", "-y", "-i", video_file, "-i", english_audio_aac,
            "-c:v", "copy", "-map", "0:v:0", "-map", "1:a:0", "-shortest",
            final_video
        ]
        subprocess.run(ffmpeg_merge_cmd, check=True)

    # ========== عرض الفيديو النهائي ==========
    st.success("🎉 تم إنشاء الفيديو بصوت احترافي!")
    st.video(final_video)

    with open(final_video, "rb") as f:
        st.download_button("⬇️ تحميل الفيديو", f, file_name="translated_video.mp4")

    # ========== تنظيف الملفات ==========
    for f in [video_file, audio_file, edge_audio_mp3, english_audio_aac]:
        if os.path.exists(f):
            os.remove(f)
