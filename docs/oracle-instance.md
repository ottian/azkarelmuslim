# إنشاء سيرفر إذاعة "أذكار المسلم" على Oracle Cloud

## 1. افتح صفحة الإنشاء
Menu ← Compute ← Instances ← **Create instance**

## 2. الاسم والمكان
- **Name**: `azkar-radio`
- **Placement**: سيبه زي ما هو. لو ظهرت رسالة **Out of capacity** جرب Availability Domain تاني، أو جرب تاني بعد شوية (دي مشكلة معروفة في الأجهزة المجانية).

## 3. النظام والجهاز
- **Image** ← Change image ← **Canonical Ubuntu 24.04** (مش Minimal).
- **Shape** ← Change shape ← **Ampere** ← `VM.Standard.A1.Flex`
  - **OCPUs**: 4
  - **Memory**: 24 GB
- لازم يظهر جنبه **Always Free-eligible**.

## 4. الشبكة
- **Create new virtual cloud network** وسيب الاسم الافتراضي.
- **Create new public subnet**.
- فعّل **Automatically assign public IPv4 address**.

## 5. مفتاح الدخول (SSH)
- اختار **Generate a key pair for me**.
- دوس **Save private key** و **Save public key** واحفظهم في مكان أمين.
- المفتاح الخاص ده زي الباسورد بالظبط: **متبعتوش لحد، ولا ليا**.

## 6. المساحة
- **Boot volume** ← فعّل **Specify a custom boot volume size** ← اكتب المساحة.
  - المجاني 200 جيجا للحساب كله. لو مفيش عندك سيرفرات تانية اكتب **200**.
  - لو عندك سيرفرات تانية اطرح مساحتها (أقل رقم مسموح 50). Oracle مش بتسمح تصغّر هارد موجود.
  - صفحة **View estimated cost** بتحسب السعر من غير ما تطرح المجاني، متقلقش منها.

## 7. Create
دوس **Create** واستنى لحد ما الحالة تبقى **Running** (أخضر).

## 8. افتح البورتات
من صفحة الـ Instance ← اسم الـ **Subnet** ← **Security Lists** ← Default Security List ← **Add Ingress Rules**:

| Source CIDR | Protocol | Port |
|---|---|---|
| `0.0.0.0/0` | TCP | 80 |
| `0.0.0.0/0` | TCP | 443 |

(بورت 22 للـ SSH بيكون مفتوح لوحده.)

## 9. ادخل على السيرفر
```bash
ssh -i path/to/private.key ubuntu@PUBLIC_IP
```
وبعدين كمّل من [README](../README.md#1-تجهيز-السيرفر).

## ملحوظة مهمة: سحب السيرفر لو مش شغال
Oracle ممكن تسحب السيرفر المجاني لو فضل استهلاكه قليل جدًا لمدة 7 أيام، والإذاعة استهلاكها قليل. الحل المضمون إنك ترقّي الحساب لـ **Pay As You Go**: الموارد المجانية بتفضل مجانية، والسيرفر مش بيتسحب. بس بيحتاج كارت، ولو عدّيت الحدود المجانية هيتحسب عليك فلوس، فلازم نظبط تنبيه ميزانية (Budget) بصفر.
