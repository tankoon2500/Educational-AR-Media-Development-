# ED401 การพัฒนาสื่อความจริงเสริมเพื่อการศึกษา (Courseware) 🎓

**ED401 Educational AR Media Development** เป็นระบบบทเรียนคอมพิวเตอร์ช่วยสอน (Courseware) รูปแบบ Web Application ที่พัฒนาขึ้นสำหรับนักศึกษาปริญญาตรี คณะครุศาสตร์ ชั้นปีที่ 3 เพื่อใช้ศึกษาเนื้อหาเกี่ยวกับการพัฒนาสื่อความจริงเสริม (Augmented Reality) แบบ Interactive

ระบบนี้มาพร้อมกับระบบจัดการเนื้อหา, แบบทดสอบ (Pre-test/Post-test), ระบบวัดพัฒนาการ (N-Gain) และระบบประเมินผลสำหรับผู้สอน โดยใช้ **Supabase** ในการจัดการฐานข้อมูล (Database) การพิสูจน์ตัวตน (Authentication) และการจัดเก็บไฟล์ (Storage)

---

## 🚀 ฟีเจอร์หลัก (Key Features)

### 🧑‍🎓 สำหรับผู้เรียน (Students)
- **ระบบเข้าสู่ระบบ/ลงทะเบียน:** เข้าใช้งานด้วยรหัสนักศึกษา (ผูกกับรายชื่อในระบบ)
- **แดชบอร์ดส่วนตัว:** ติดตามความก้าวหน้าในการเรียนและดูสรุปผลคะแนน
- **ระบบแบบทดสอบอัจฉริยะ:** ข้อสอบแบบสุ่มชุด (คู่/คี่) สำหรับทดสอบก่อนเรียนและหลังเรียน พร้อมคำถามแทรกระหว่างเรียน
- **เนื้อหาบทเรียน 5 หน่วย:** เรียนรู้เนื้อหาและตอบคำถามท้ายหน่วยเพื่อปลดล็อกเนื้อหาถัดไป
- **การส่งงานปฏิบัติ (WebAR):** ส่งผลงานได้ทั้งรูปแบบ Link (URL) หรือแนบไฟล์ภาพ/วิดีโอ (ไม่เกิน 20MB)
- **แหล่งทรัพยากรเพิ่มเติม:** ดาวน์โหลดและดูสื่อเสริมที่ผู้สอนจัดเตรียมไว้

### 👨‍🏫 สำหรับผู้สอน (Teachers)
- **ภาพรวมผลการเรียน (Dashboard):** ดูสรุปคะแนน Pre-test, Post-test และพัฒนาการสัมพัทธ์ (Normalized Gain) ของผู้เรียนทุกคน
- **ระบบตรวจงาน:** ตรวจและให้คะแนนงานภาคปฏิบัติ (Unit 4) พร้อมช่องสำหรับแสดงความคิดเห็น
- **ระบบจัดการสื่อการเรียน:** อัปโหลดหรือเพิ่มลิงก์แหล่งข้อมูล (PDF, PPTX, Video) ขนาดไม่เกิน 50MB
- **ระบบส่งออกข้อมูล (Export CSV):** ส่งออกผลคะแนนทั้งหมดเป็นไฟล์ CSV ที่รองรับภาษาไทย (BOM)

---

## 🛠️ โครงสร้างทางเทคนิค (Tech Stack)

*   **Frontend:** HTML5, CSS3 (Tailwind CSS ผ่าน CDN), Vanilla JavaScript
*   **3D / AR Rendering:** `<model-viewer>` (Google)
*   **Backend & Database:** Supabase (PostgreSQL)
*   **Authentication:** Supabase Auth (Email / Password)
*   **Storage:** Supabase Storage (รองรับระบบ Signed URL)
*   **Security:** Row Level Security (RLS), โครงสร้างแบบ Security Definer 

---

## ⚙️ การติดตั้งและเริ่มต้นใช้งาน (Getting Started)

การตั้งค่าโปรเจกต์นี้ใช้เวลาเพียงไม่กี่นาที โดยไม่จำเป็นต้องใช้ Node.js หรือ Build tools ใดๆ

### 1. การตั้งค่า Supabase
1. สร้างโปรเจกต์ใหม่ที่ [Supabase](https://supabase.com/)
2. ไปที่ `Authentication` > `Providers` > `Email` และ **ปิด (Disable)** ตัวเลือก `Confirm email` และ `Secure email change`
3. ไปที่ `SQL Editor` นำโค้ดจากไฟล์ `setup.sql` ไปวางแล้วกด **Run**
4. หากต้องการเพิ่มรายชื่อนักศึกษา ให้ไปที่ `Table Editor` > ตาราง `students` แล้วใช้เมนู **Import data from CSV**

### 2. การตั้งค่าฝั่งผู้สอน (Teacher Account)
1. เปิดหน้าเว็บ (รันไฟล์ HTML) และทำการสมัครสมาชิกด้วยอีเมลสำหรับผู้สอน
2. ไปที่ Supabase `Authentication` > `Users` และคัดลอก `User UID`
3. นำ UID ไปวางและรันคำสั่ง SQL ต่อไปนี้ใน `SQL Editor`:
   ```sql
   INSERT INTO teachers (user_id) VALUES ('ใส่-UID-ตรงนี้');
   ```

### 3. การเชื่อมต่อ Frontend
1. ไปที่ Supabase `Project Settings` > `API`
2. คัดลอก `Project URL` และ `anon public key`
3. เปิดไฟล์ `courseware.html` ด้วย Text Editor
4. วางค่าที่คัดลอกมาในตัวแปรส่วนต้นของสคริปต์:
   ```javascript
   const SUPABASE_URL = 'YOUR_SUPABASE_URL'; 
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```

### 4. การรันโปรเจกต์
ดับเบิลคลิกไฟล์ `courseware.html` เพื่อเปิดผ่าน Web Browser (แนะนำ Google Chrome) หรือใช้งานผ่าน Local Server (เช่น VS Code Live Server)

---

## 🔒 ความปลอดภัย (Security Notes)

- ระบบใช้ **Row Level Security (RLS)** ของ PostgreSQL อย่างเข้มงวด ผู้เรียนไม่สามารถเข้าถึง ลบ หรือแก้ไขข้อมูล/ไฟล์ของผู้เรียนคนอื่นได้
- การเปลี่ยนแปลงคะแนน (`score`) ถูกล็อคด้วย Trigger ระดับฐานข้อมูล (`protect_submission_grading`) นักศึกษาไม่สามารถใช้ Inspect Element แก้ไขคะแนนได้
- ไม่มีการใช้งาน Service Role Key ใน Frontend โดยเด็ดขาด

---

## 📚 แหล่งอ้างอิงทางวิชาการ (Academic References)
เนื้อหาภายในระบบอ้างอิงจากหลักวิชาการดังนี้:
*   **Azuma (1997):** องค์ประกอบ 3 ประการของ Augmented Reality
*   **Milgram & Kishino (1994):** แนวคิด Reality-Virtuality Continuum
*   **Mayer:** หลักการออกแบบสื่อมัลติมีเดีย (Coherence Principle / Cognitive Load)
*   **Rovinelli & Hambleton (1977):** การหาค่าดัชนีความสอดคล้อง (IOC)
*   **Hake (1998):** การหาค่าพัฒนาการสัมพัทธ์ (Normalized Gain)