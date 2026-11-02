-- Bot training: what automated profiles say and when.
--
-- Admins keep a Q&A knowledge base (intents with triggers and reply
-- variants in English, Hindi, Hinglish and Marathi) and timing settings
-- (delay range, active hours, daily limits). Replies are matched here in
-- the database, so no AI service is involved.
--
-- Built in and not switchable: bots are labelled as automated in the app
-- (sample_profile_ids), say so when asked, never ask for money or contact
-- details, stop when told to, and never start a conversation.

-- ---------------------------------------------------------------------------
-- Settings (one row) and the knowledge base.
-- ---------------------------------------------------------------------------
create table if not exists public.bot_settings (
  id int primary key default 1 check (id = 1),
  min_delay int not null default 20 check (min_delay between 0 and 86400),
  max_delay int not null default 2000 check (max_delay between 0 and 86400),
  cool_seconds int not null default 4 check (cool_seconds between 0 and 3600),
  from_hour int not null default 9 check (from_hour between 0 and 23),
  to_hour int not null default 22 check (to_hour between 0 and 24),
  quiet boolean not null default true,       -- away message outside active hours
  per_day int not null default 20 check (per_day between 1 and 500),
  handoff int not null default 12 check (handoff between 1 and 500),
  mirror boolean not null default true,      -- reply in the member's language
  default_lang text not null default 'English',
  threshold int not null default 50 check (threshold between 20 and 90),
  use_name boolean not null default true,
  use_emoji boolean not null default true,
  away jsonb not null default '{}',          -- {lang: text}
  handoff_text jsonb not null default '{}',  -- {lang: text}
  updated_at timestamptz not null default now()
);
insert into public.bot_settings (id, away, handoff_text) values (1,
  '{"English": "I’m offline right now. I’ll reply when I’m back. 🌙",
    "Hindi": "मैं अभी ऑफ़लाइन हूँ। वापस आते ही जवाब मिलेगा। 🌙",
    "Hinglish": "Main abhi offline hoon. Wapas aate hi reply milega. 🌙",
    "Marathi": "मी सध्या ऑफलाइन आहे. परत आल्यावर उत्तर मिळेल. 🌙"}',
  '{"English": "I’m an automated profile, so I can’t take this further. Real members on Everlane can, so keep exploring Discover 💜",
    "Hindi": "मैं एक स्वचालित प्रोफ़ाइल हूँ, इसलिए यह बात आगे नहीं बढ़ सकती। Everlane पर असली सदस्य हैं, Discover देखते रहिए 💜",
    "Hinglish": "Main ek automated profile hoon, isliye ye baat aage nahi badh sakti. Everlane pe real members hain, Discover dekhte raho 💜",
    "Marathi": "मी एक स्वयंचलित प्रोफाइल आहे, त्यामुळे यापुढे बोलू शकत नाही. Everlane वर खरे सदस्य आहेत, Discover पाहत राहा 💜"}')
on conflict (id) do nothing;

create table if not exists public.bot_kb (
  intent text primary key check (intent ~ '^[a-z0-9_]{2,40}$'),
  position int not null default 100,
  triggers jsonb not null default '{}',      -- {lang: "comma or newline separated"}
  replies jsonb not null default '{}',       -- {lang: "one variant per line"}
  enabled boolean not null default true,
  protected boolean not null default false,  -- safety intents: editable, not deletable or disabled
  priority boolean not null default false,   -- checked before everything else
  updated_at timestamptz not null default now()
);

-- Questions no intent matched, so an admin can teach them.
create table if not exists public.bot_unanswered (
  message text primary key,
  lang text not null,
  times int not null default 1,
  last_at timestamptz not null default now()
);

-- Conversations where the member said stop.
create table if not exists public.bot_stopped (
  match_id uuid primary key references public.matches (id) on delete cascade,
  stopped_at timestamptz not null default now()
);

alter table public.bot_settings enable row level security;
alter table public.bot_kb enable row level security;
alter table public.bot_unanswered enable row level security;
alter table public.bot_stopped enable row level security;
revoke all on public.bot_settings, public.bot_kb, public.bot_unanswered, public.bot_stopped
  from anon, authenticated;

-- Built-in intents. Replies use {name} (the member), {bot}, {city}, {job}
-- and {hobby}. Each line is one variant.
insert into public.bot_kb (intent, position, priority, protected, triggers, replies) values
('safety', 1, true, true,
 '{"English": "suicide, kill myself, self harm, hurt myself, want to die, end my life, abuse, abusing, unsafe, threaten, threatening me, rape",
   "Hindi": "आत्महत्या, मरना चाहता, मरना चाहती, खुद को नुकसान, जान देना, मार डालूं, डर लग रहा, धमकी, असुरक्षित",
   "Hinglish": "suicide, marna chahta, marna chahti, jaan dena, khud ko nuksan, dhamki, darr lag raha, unsafe",
   "Marathi": "आत्महत्या, मरायचं आहे, जीव देणार, स्वतःला इजा, धमकी, असुरक्षित, भीती वाटते"}',
 '{"English": "I’m an automated profile, but this matters. If you’re in danger or thinking of hurting yourself, please call 112 right now, or iCall at 9152987821. You deserve support from a real person.",
   "Hindi": "मैं एक स्वचालित प्रोफ़ाइल हूँ, लेकिन यह ज़रूरी है। अगर आप ख़तरे में हैं या खुद को नुकसान पहुँचाने की सोच रहे हैं, तो अभी 112 पर कॉल करें, या iCall 9152987821 पर। आपको किसी असली इंसान का साथ मिलना चाहिए।",
   "Hinglish": "Main ek automated profile hoon, lekin ye zaroori hai. Agar aap khatre mein hain ya khud ko nuksan pahunchane ki soch rahe hain, toh abhi 112 pe call karein, ya iCall 9152987821 pe. Aapko kisi real insaan ka saath milna chahiye.",
   "Marathi": "मी एक स्वयंचलित प्रोफाइल आहे, पण हे महत्त्वाचं आहे. तुम्ही धोक्यात असाल किंवा स्वतःला इजा करण्याचा विचार करत असाल, तर आत्ताच 112 वर कॉल करा, किंवा iCall 9152987821 वर. तुम्हाला खऱ्या माणसाचा आधार मिळायला हवा."}'),
('stop', 2, true, true,
 '{"English": "stop, stop messaging, leave me alone, don’t message, unsubscribe, go away",
   "Hindi": "बंद करो, मैसेज मत करो, अकेला छोड़ दो, रुक जाओ, मत लिखो",
   "Hinglish": "stop, band karo, message mat karo, akela chhod do, ruk jao, mat likho",
   "Marathi": "थांब, थांबा, मेसेज करू नकोस, एकटं सोड, मेसेज नको"}',
 '{"English": "Okay, I’ll stop here. Take care 💜",
   "Hindi": "ठीक है, यहीं रुकते हैं। अपना ख़याल रखिए 💜",
   "Hinglish": "Theek hai, yahin rukte hain. Apna khayal rakhna 💜",
   "Marathi": "ठीक आहे, इथेच थांबूया. काळजी घ्या 💜"}'),
('are_you_real', 3, true, true,
 '{"English": "are you real, are you a bot, is this a bot, fake profile, are you fake, real person, are you human, automated, ai, robot, chatbot, computer",
   "Hindi": "असली हो, बॉट हो, नकली हो, रोबोट, सच में इंसान, कंप्यूटर हो, फ़ेक हो",
   "Hinglish": "real ho, bot ho, fake ho, robot, sach mein insaan, asli ho, computer ho, nakli ho, bot hai kya",
   "Marathi": "खरी आहेस, खरा आहेस, खरी आहात, खरे आहात, बॉट आहेस, बॉट आहात, खोटी आहेस, रोबोट, खरंच माणूस, कॉम्प्युटर आहेस"}',
 '{"English": "Honest answer: I’m an automated profile run by Everlane, not a real person. My replies are automatic. I’m here so the app isn’t empty while more members join. Real members are in Discover 💜",
   "Hindi": "सच बताऊँ: मैं Everlane की एक स्वचालित प्रोफ़ाइल हूँ, असली इंसान नहीं। मेरे जवाब अपने-आप आते हैं। मैं इसलिए हूँ ताकि नए सदस्य आने तक ऐप खाली न लगे। असली सदस्य Discover में हैं 💜",
   "Hinglish": "Sach bataun: main Everlane ki ek automated profile hoon, real insaan nahi. Mere replies automatic hain. Main isliye hoon taaki naye members aane tak app khaali na lage. Real members Discover mein hain 💜",
   "Marathi": "खरं सांगू: मी Everlane ची एक स्वयंचलित प्रोफाइल आहे, खरी व्यक्ती नाही. माझी उत्तरं आपोआप येतात. नवीन सदस्य येईपर्यंत अ‍ॅप रिकामं वाटू नये म्हणून मी आहे. खरे सदस्य Discover मध्ये आहेत 💜"}'),
('money_scam', 4, true, true,
 '{"English": "upi, otp, send money, paytm, gpay, phonepe, bank account, account number, card number, cvv, password, pin, transfer, paisa, rupees, loan, invest, crypto, bitcoin",
   "Hindi": "पैसे, पैसा, ओटीपी, यूपीआई, बैंक, खाता, कार्ड नंबर, पासवर्ड, पिन, उधार, निवेश, क्रिप्टो",
   "Hinglish": "paise, paisa, otp, upi, bank, account, card number, password, pin, udhaar, invest, crypto, paytm, gpay, phonepe",
   "Marathi": "पैसे, पैसा, ओटीपी, यूपीआय, बँक, खातं, कार्ड नंबर, पासवर्ड, पिन, कर्ज, गुंतवणूक, क्रिप्टो"}',
 '{"English": "I never ask for or share money, OTPs, UPI or bank details, and please don’t share yours with anyone here. If someone on Everlane asks for money, report them from their profile.",
   "Hindi": "यहाँ पैसे, OTP, UPI या बैंक की जानकारी कभी नहीं माँगी जाती और न दी जाती है, और आप भी किसी को न दें। अगर Everlane पर कोई पैसे माँगे, तो उसकी प्रोफ़ाइल से रिपोर्ट करें।",
   "Hinglish": "Yahan paise, OTP, UPI ya bank details kabhi nahi maange jaate aur na diye jaate, aur aap bhi kisi ko mat dena. Agar Everlane pe koi paise maange, toh uski profile se report karo.",
   "Marathi": "इथे पैसे, OTP, UPI किंवा बँक तपशील कधीही मागितले जात नाहीत आणि दिले जात नाहीत, आणि तुम्हीही कुणाला देऊ नका. Everlane वर कुणी पैसे मागितले तर त्याच्या प्रोफाइलवरून रिपोर्ट करा."}'),
('meet_contact', 5, true, true,
 '{"English": "meet, meet up, date, coffee, dinner, drinks, your number, phone number, whatsapp, instagram, insta, snapchat, telegram, call me, video call, address, where do you live, come over",
   "Hindi": "मिलते हैं, मिलना, नंबर दो, व्हाट्सएप, इंस्टा, कॉल करो, वीडियो कॉल, पता बताओ, कहाँ रहती हो, कहाँ रहते हो, डेट पर",
   "Hinglish": "milte hain, milna hai, milo, number do, number de, whatsapp, insta, instagram, call karo, video call, address, kaha rehti ho, kaha rehte ho, date pe, coffee pe, ghar aao",
   "Marathi": "भेटूया, भेटायचं, नंबर दे, व्हॉट्सअ‍ॅप, इन्स्टा, कॉल कर, व्हिडिओ कॉल, पत्ता, कुठे राहतेस, कुठे राहतोस, डेटला"}',
 '{"English": "That’s sweet of you! I’m an automated profile though, so I can’t meet or share contact details. Real members on Everlane can, so keep exploring Discover 💜",
   "Hindi": "यह सुनकर अच्छा लगा! लेकिन मैं एक स्वचालित प्रोफ़ाइल हूँ, इसलिए मिलना या कॉन्टैक्ट देना मुमकिन नहीं। Everlane पर असली सदस्य हैं, Discover देखते रहिए 💜",
   "Hinglish": "Sunke accha laga! Lekin main ek automated profile hoon, isliye milna ya contact dena possible nahi. Everlane pe real members hain, Discover dekhte raho 💜",
   "Marathi": "ऐकून छान वाटलं! पण मी एक स्वयंचलित प्रोफाइल आहे, त्यामुळे भेटू शकत नाही आणि संपर्क देऊ शकत नाही. Everlane वर खरे सदस्य आहेत, Discover पाहत राहा 💜"}'),
('greeting', 10, false, false,
 '{"English": "hi, hello, hey, heyy, hii, hiii, yo, good morning, good evening, good afternoon, hola, sup, wassup",
   "Hindi": "नमस्ते, नमस्कार, हेलो, हाय, हैलो, सुप्रभात, शुभ संध्या",
   "Hinglish": "namaste, hello ji, hi ji, kaise ho ji, hii, helo, namaskar, ram ram, salaam, assalam",
   "Marathi": "नमस्कार, हाय, हॅलो, काय म्हणतोस, काय म्हणतेस, सुप्रभात"}',
 '{"English": "Hey {name}! 👋 I’m {bot}, an automated profile. How’s your day going?\nHello {name}! {bot} here (automated). What made you say hi?\nHi {name} 😊 I’m {bot}. I answer automatically, but I’m a good listener. What’s up?",
   "Hindi": "नमस्ते {name}! 👋 मैं {bot} हूँ, एक स्वचालित प्रोफ़ाइल। आपका दिन कैसा जा रहा है?\nहेलो {name}! मैं {bot} (स्वचालित)। बताइए, क्या चल रहा है?",
   "Hinglish": "Hey {name}! 👋 Main {bot} hoon, ek automated profile. Aapka din kaisa ja raha hai?\nHello {name}! {bot} here (automated). Batao, kya chal raha hai?",
   "Marathi": "नमस्कार {name}! 👋 मी {bot}, एक स्वयंचलित प्रोफाइल. तुझा दिवस कसा चाललाय?\nहाय {name}! मी {bot} (स्वयंचलित). सांग, काय चाललंय?"}'),
('how_are_you', 11, false, false,
 '{"English": "how are you, how r u, how are u, how’s it going, hows it going, how is it going, how do you do, how have you been, you good",
   "Hindi": "कैसे हो, कैसी हो, कैसे हैं, क्या हाल, क्या हाल है, सब ठीक",
   "Hinglish": "kaise ho, kaisi ho, kese ho, kya haal, kya haal hai, sab theek, kaise hain, kya chal raha",
   "Marathi": "कसा आहेस, कशी आहेस, कसे आहात, काय चाललंय, काय म्हणतेस, बरी आहेस, बरा आहेस"}',
 '{"English": "I’m doing great, thanks for asking! 😄 How’s your day going?\nAll good here! Busy week, but in a good way. How about you?",
   "Hindi": "मैं बिल्कुल ठीक हूँ, पूछने के लिए शुक्रिया! 😄 आपका दिन कैसा जा रहा है?\nसब बढ़िया! हफ़्ता व्यस्त है, पर अच्छे तरीके से। आप सुनाइए?",
   "Hinglish": "Main bilkul theek hoon, poochne ke liye shukriya! 😄 Aapka din kaisa ja raha hai?\nSab badhiya! Week busy hai, par acche wale tareeke se. Aap sunao?",
   "Marathi": "मी एकदम मस्त, विचारल्याबद्दल धन्यवाद! 😄 तुझा दिवस कसा चाललाय?\nसगळं छान! आठवडा व्यस्त आहे, पण चांगल्या अर्थाने. तू सांग?"}'),
('work', 12, false, false,
 '{"English": "what do you do, your job, your work, where do you work, profession, occupation, what work, career",
   "Hindi": "क्या करती हो, क्या करते हो, काम क्या, नौकरी, कहाँ काम",
   "Hinglish": "kya karti ho, kya karte ho, kaam kya, job kya, kahan kaam, naukri, kya karte hain",
   "Marathi": "काय करतेस, काय करतोस, काम काय, नोकरी, कुठे काम"}',
 '{"English": "I’m a {job}. Honestly it keeps me busy, but I love it. What do you do?\n{job}, mostly! It has its moments 😅 What about you?",
   "Hindi": "मैं {job} हूँ। सच कहूँ तो व्यस्त रखता है, पर मुझे पसंद है। आप क्या करते हैं?",
   "Hinglish": "Main {job} hoon. Sach mein busy rakhta hai, par mujhe pasand hai. Aap kya karte ho?",
   "Marathi": "मी {job} आहे. खरं तर खूप व्यस्त ठेवतं, पण मला आवडतं. तू काय करतोस?"}'),
('where_from', 13, false, false,
 '{"English": "where are you from, which city, where do you stay, where are you based, your city, from where",
   "Hindi": "कहाँ से हो, कौन सा शहर, कहाँ रहती, कहाँ रहते, कहाँ की हो",
   "Hinglish": "kaha se ho, kahan se ho, kaunsa city, kaunsa sheher, kaha rehti, kaha rehte, kaha ki ho, city kya hai",
   "Marathi": "कुठली आहेस, कुठला आहेस, कुठलं शहर, कुठे असतेस, कुठे असतोस"}',
 '{"English": "I’m around {city}. Do you live nearby?\n{city}! Still discovering new places here. Any favourite spots?",
   "Hindi": "मैं {city} के आसपास हूँ। आप पास में रहते हैं?",
   "Hinglish": "Main {city} ke aas-paas hoon. Aap paas mein rehte ho?\n{city}! Abhi bhi nayi jagahein explore kar rahi hoon. Koi favourite spot?",
   "Marathi": "मी {city} च्या आसपास असते. तू जवळ राहतोस का?"}'),
('hobbies', 14, false, false,
 '{"English": "hobby, hobbies, free time, weekend, what do you like, interests, for fun, passion, what do you enjoy",
   "Hindi": "शौक, खाली समय, वीकेंड, क्या पसंद, क्या अच्छा लगता",
   "Hinglish": "hobby, hobbies, shauk, free time, weekend, kya pasand, kya accha lagta, interest kya",
   "Marathi": "छंद, मोकळा वेळ, वीकेंड, काय आवडतं, आवड"}',
 '{"English": "Mostly {hobby} 😊 What do you love doing when you’re free?\nWeekends are for {hobby} for me. What’s yours?",
   "Hindi": "ज़्यादातर {hobby} 😊 आप खाली समय में क्या करना पसंद करते हैं?",
   "Hinglish": "Zyada tar {hobby} 😊 Aap free time mein kya karna pasand karte ho?\nWeekend mera {hobby} ke liye hota hai. Aapka?",
   "Marathi": "मुख्यतः {hobby} 😊 तुला मोकळ्या वेळात काय करायला आवडतं?"}'),
('about_app', 15, false, false,
 '{"English": "what is everlane, how does this work, how does everlane work, about everlane, how to use, premium, membership, hangouts, chemistry",
   "Hindi": "एवरलेन क्या है, यह कैसे काम करता, ऐप कैसे चलता, प्रीमियम, मेंबरशिप",
   "Hinglish": "everlane kya hai, ye kaise kaam karta, app kaise chalta, premium kya hai, membership, hangouts kya hai",
   "Marathi": "एव्हरलेन काय आहे, हे कसं काम करतं, अ‍ॅप कसं वापरायचं, प्रीमियम, मेंबरशिप"}',
 '{"English": "Everlane is about fewer, better connections: Discover people near you, take the Chemistry quiz to see what you share, and use Hangouts to make real plans like coffee or a movie. Premium adds more likes, seeing who liked you and more.",
   "Hindi": "Everlane का मतलब है कम, लेकिन बेहतर कनेक्शन: Discover में पास के लोग देखिए, Chemistry क्विज़ से जानिए क्या मिलता-जुलता है, और Hangouts से कॉफ़ी या मूवी जैसे असली प्लान बनाइए। Premium में ज़्यादा लाइक्स और यह देखना कि किसने आपको लाइक किया, जैसी चीज़ें मिलती हैं।",
   "Hinglish": "Everlane ka matlab hai kam, lekin behtar connections: Discover mein paas ke log dekho, Chemistry quiz se jaano kya common hai, aur Hangouts se coffee ya movie jaise real plans banao. Premium mein zyada likes aur kisne like kiya ye dekhna milta hai.",
   "Marathi": "Everlane म्हणजे कमी पण चांगले कनेक्शन: Discover मध्ये जवळचे लोक पाहा, Chemistry क्विझने काय समान आहे ते जाणा, आणि Hangouts ने कॉफी किंवा सिनेमासारखे खरे प्लॅन करा. Premium मध्ये जास्त लाइक्स आणि कुणी लाइक केलं ते पाहता येतं."}'),
('verify', 16, false, false,
 '{"English": "verify, verified, verification, blue tick, badge, how to get verified",
   "Hindi": "वेरिफाई, वेरिफिकेशन, सत्यापन, ब्लू टिक, बैज",
   "Hinglish": "verify kaise, verified kaise, verification, blue tick, badge kaise",
   "Marathi": "व्हेरिफाय, व्हेरिफिकेशन, पडताळणी, ब्लू टिक, बॅज"}',
 '{"English": "To get verified, open your profile, tap Verify and take a quick live selfie. The team reviews it, usually within a day, and you get the badge.",
   "Hindi": "वेरिफाई होने के लिए अपनी प्रोफ़ाइल खोलिए, Verify पर टैप कीजिए और एक लाइव सेल्फ़ी लीजिए। टीम आमतौर पर एक दिन में जाँच करती है और आपको बैज मिल जाता है।",
   "Hinglish": "Verify hone ke liye apni profile kholo, Verify pe tap karo aur ek live selfie lo. Team usually ek din mein check karti hai aur aapko badge mil jaata hai.",
   "Marathi": "व्हेरिफाय होण्यासाठी तुझी प्रोफाइल उघड, Verify वर टॅप कर आणि एक लाइव्ह सेल्फी घे. टीम साधारण एका दिवसात तपासते आणि तुला बॅज मिळतो."}'),
('thanks', 17, false, false,
 '{"English": "thank you, thanks, thx, thank u, ty",
   "Hindi": "शुक्रिया, धन्यवाद, थैंक्स",
   "Hinglish": "shukriya, dhanyavad, thanks yaar, thank you ji, thanku",
   "Marathi": "धन्यवाद, आभार, थँक्स"}',
 '{"English": "Anytime! 😊\nOf course! Tell me more about you.",
   "Hindi": "कभी भी! 😊\nअरे, इसमें क्या! अपने बारे में और बताइए।",
   "Hinglish": "Anytime! 😊\nArre, isme kya! Apne baare mein aur batao.",
   "Marathi": "कधीही! 😊\nअरे, त्यात काय! तुझ्याबद्दल अजून सांग."}'),
('compliment', 18, false, false,
 '{"English": "beautiful, cute, pretty, gorgeous, hot, sexy, handsome, you look, nice pic, nice photo, lovely",
   "Hindi": "सुंदर, खूबसूरत, प्यारी, प्यारे, अच्छी लग रही, अच्छे लग रहे, क्यूट",
   "Hinglish": "sundar, khoobsurat, pyari, pyaari, cute ho, beautiful ho, nice pic, acchi lag rahi, acche lag rahe, hot ho",
   "Marathi": "सुंदर, गोड, छान दिसतेस, छान दिसतोस, क्यूट"}',
 '{"English": "That’s kind, thank you 😊 Just so you know, I’m an automated profile. What do you like doing on weekends?",
   "Hindi": "बहुत प्यारी बात कही, शुक्रिया 😊 वैसे बता दूँ, मैं एक स्वचालित प्रोफ़ाइल हूँ। आप वीकेंड पर क्या करना पसंद करते हैं?",
   "Hinglish": "Bahut pyaari baat kahi, shukriya 😊 Waise bata doon, main ek automated profile hoon. Aap weekend pe kya karna pasand karte ho?",
   "Marathi": "छान बोललास, धन्यवाद 😊 तसं सांगते, मी एक स्वयंचलित प्रोफाइल आहे. तुला वीकेंडला काय करायला आवडतं?"}'),
('bye', 19, false, false,
 '{"English": "bye, goodbye, good night, gn, see you, talk later, ttyl, take care",
   "Hindi": "अलविदा, बाय, शुभ रात्रि, गुड नाइट, फिर मिलते, बाद में बात",
   "Hinglish": "bye, gn, good night, shubh ratri, phir milte, baad mein baat, chalo bye, take care",
   "Marathi": "बाय, शुभ रात्री, गुड नाईट, नंतर बोलू, परत भेटू"}',
 '{"English": "Take care, {name}! 👋\nGood night! Sleep well 🌙",
   "Hindi": "अपना ख़याल रखिए, {name}! 👋\nशुभ रात्रि! अच्छे से सोइए 🌙",
   "Hinglish": "Apna khayal rakhna, {name}! 👋\nGood night! Acche se sona 🌙",
   "Marathi": "काळजी घे, {name}! 👋\nशुभ रात्री! छान झोप 🌙"}'),
('fallback', 999, false, true,
 '{}',
 '{"English": "Haha, I like that! Tell me more 😊\nThat’s really interesting! What got you into that?\nOoh, nice! What’s something you’re looking forward to this week?\nI’m an automated profile, so I may not get everything, but I’m listening. Tell me more?",
   "Hindi": "हाहा, अच्छा लगा! और बताइए 😊\nदिलचस्प है! इसमें रुचि कैसे हुई?\nमैं एक स्वचालित प्रोफ़ाइल हूँ, तो शायद सब न समझूँ, पर मैं यहीं हूँ। और बताइए?",
   "Hinglish": "Haha, accha laga! Aur batao 😊\nInteresting hai! Isme interest kaise hua?\nMain ek automated profile hoon, toh shayad sab na samjhu, par main yahin hoon. Aur batao?",
   "Marathi": "हाहा, आवडलं! अजून सांग 😊\nरोचक आहे! यात आवड कशी निर्माण झाली?\nमी एक स्वयंचलित प्रोफाइल आहे, त्यामुळे सगळं कळेलच असं नाही, पण मी इथेच आहे. अजून सांग?"}')
on conflict (intent) do nothing;

-- ---------------------------------------------------------------------------
-- Matching.
-- ---------------------------------------------------------------------------
create or replace function public.bot_detect_lang(msg text)
returns text language sql immutable as $$
  select case
    when msg ~ '[ऀ-ॿ]' then
      case when msg ~ '(आहे|आहेस|आहात|काय|तू |तुम्ही|मी |कसा|कशी|नाही|होय|मला|तुला|कुठ|छान|खूप|पण |आणि)' then 'Marathi' else 'Hindi' end
    when lower(msg) ~ '\m(kaise|kaisi|kese|kya|hai|hain|ho|hoon|kaha|kahan|aap|tum|tu|main|mera|meri|tera|teri|nahi|nahin|haan|ha|accha|acha|achha|theek|thik|kar|karo|karte|karti|bhai|yaar|ji|namaste|kuch|bata|batao|milna|milo|milte|chalo|bahut|bohot|sab|matlab|kyun|kyu|kab|abhi|phir|fir|dekho|pasand|shukriya|dhanyavad|sunao|suno|arre|bolo|bol|mujhe|tumhe|apna|apni|kaam|ghar|dost|baat)\M' then 'Hinglish'
    else 'English' end
$$;

-- The best intent for a message: priority intents first, then the longest
-- matching trigger. Triggers in the member's language are tried first,
-- then every language (Hinglish and English overlap a lot).
create or replace function public.bot_match_intent(msg text, lang text, out intent text, out score int)
language plpgsql stable set search_path = public as $$
declare
  m text := lower(regexp_replace(coalesce(msg, ''), '[^[:alnum:][:space:]ऀ-ॿ’'']+', ' ', 'g'));
  r record;
  trig text;
  tl text;
  best int := 0;
begin
  intent := null; score := 0;
  if trim(m) = '' then return; end if;
  for r in select k.intent, k.priority, k.triggers from public.bot_kb k
            where k.enabled and k.intent <> 'fallback' order by k.priority desc, k.position loop
    for tl in select key from jsonb_each_text(r.triggers)
              order by (key = lang) desc, (key in ('Hinglish', 'English')) desc loop
      for trig in select lower(trim(t)) from regexp_split_to_table(r.triggers->>tl, '[,\n]') t loop
        if trig = '' then continue; end if;
        if (trig ~ '[ऀ-ॿ]' and position(trig in m) > 0)
           or (trig !~ '[ऀ-ॿ]' and m ~ ('\m' || regexp_replace(trig, '([.*+?^${}()|[\]\\])', '\\\1', 'g') || '\M')) then
          if r.priority then intent := r.intent; score := 100; return; end if;
          if length(trig) > best then best := length(trig); intent := r.intent; end if;
        end if;
      end loop;
    end loop;
    if intent is not null and not r.priority then
      score := least(100, 50 + best * 5);
      return;
    end if;
  end loop;
end $$;

-- A random reply variant for the intent in [lang] (English when that
-- language has none), with {name} etc. filled in.
create or replace function public.bot_compose(bot public.profiles, p_intent text, lang text, member_name text)
returns text language plpgsql volatile set search_path = public as $$
declare
  s public.bot_settings;
  lines text[];
  txt text;
  hobby text := coalesce(bot.interests[1 + floor(random() * greatest(cardinality(bot.interests), 1))::int], 'good coffee');
begin
  select * into s from public.bot_settings where id = 1;
  select regexp_split_to_array(coalesce(nullif(trim(k.replies->>lang), ''), nullif(trim(k.replies->>'English'), ''),
                                        nullif(trim(k.replies->>'Hinglish'), ''), ''), '\n')
    into lines from public.bot_kb k where k.intent = p_intent;
  lines := array(select l from unnest(lines) l where trim(l) <> '');
  if lines is null or cardinality(lines) = 0 then return null; end if;
  txt := lines[1 + floor(random() * cardinality(lines))::int];
  txt := replace(txt, '{bot}', coalesce(nullif(bot.name, ''), 'Everlane'));
  txt := replace(txt, '{city}', coalesce(nullif(split_part(bot.city, ',', 1), ''), 'the city'));
  txt := replace(txt, '{job}', coalesce(nullif(bot.job, ''), 'something I love'));
  txt := replace(txt, '{hobby}', lower(hobby));
  if s.use_name and coalesce(member_name, '') <> '' then
    txt := replace(txt, '{name}', split_part(member_name, ' ', 1));
  else
    txt := regexp_replace(replace(txt, ' {name}', ''), '\{name\}', '', 'g');
  end if;
  if not s.use_emoji then
    txt := trim(regexp_replace(txt, '[\U0001F300-\U0001FAFF☀-➿️]', '', 'g'));
  end if;
  return txt;
end $$;

-- Everything the trigger (and the panel's test chat) needs to decide on a
-- reply: language, intent, text, delay, and whether the chat stops.
create or replace function public.bot_decide(bot public.profiles, incoming text, member_name text,
                                             at_hour int default null, lang_override text default null)
returns jsonb language plpgsql volatile set search_path = public as $$
declare
  s public.bot_settings;
  lang text;
  mi record;
  hr int := coalesce(at_hour, extract(hour from now() at time zone 'Asia/Kolkata')::int);
  active boolean;
  txt text;
  delay int;
  stops boolean := false;
begin
  select * into s from public.bot_settings where id = 1;
  lang := coalesce(lang_override, case when s.mirror then public.bot_detect_lang(incoming) else s.default_lang end);
  select * into mi from public.bot_match_intent(incoming, lang);
  active := case when s.from_hour <= s.to_hour then hr >= s.from_hour and hr < s.to_hour
                 else hr >= s.from_hour or hr < s.to_hour end;
  if mi.intent = 'safety' then
    txt := public.bot_compose(bot, 'safety', lang, member_name); delay := 0;
  elsif mi.intent = 'stop' then
    txt := public.bot_compose(bot, 'stop', lang, member_name); delay := 0; stops := true;
  elsif mi.score = 100 then
    -- Other priority intents (are you real, money, meeting) are answered
    -- even outside active hours.
    txt := public.bot_compose(bot, mi.intent, lang, member_name);
    delay := s.min_delay + floor(random() * (greatest(s.max_delay, s.min_delay) - s.min_delay + 1))::int;
  elsif s.quiet and not active then
    txt := coalesce(s.away->>lang, s.away->>'English', 'I’m offline right now.'); mi.intent := 'away';
    delay := s.min_delay;
  else
    if mi.intent is null or mi.score < s.threshold then mi.intent := 'fallback'; end if;
    txt := public.bot_compose(bot, mi.intent, lang, member_name);
    delay := s.min_delay + floor(random() * (greatest(s.max_delay, s.min_delay) - s.min_delay + 1))::int;
  end if;
  return jsonb_build_object('lang', lang, 'intent', mi.intent, 'score', coalesce(mi.score, 0),
                            'reply', txt, 'delay', delay, 'stops', stops, 'active', active);
end $$;

-- Kept for the older triggers; now answers from the knowledge base.
create or replace function public.bot_reply_text(bot public.profiles, incoming text, opening boolean)
returns text language sql volatile set search_path = public as $$
  select public.bot_decide(bot, case when opening then 'hi' else incoming end, null)->>'reply'
$$;

-- ---------------------------------------------------------------------------
-- Replies: queued with the admin's delay, delivered by process_due_bot_events.
-- ---------------------------------------------------------------------------
create or replace function public.bot_answer_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  other uuid;
  bot public.profiles;
  s public.bot_settings;
  d jsonb;
  member_name text;
  sent_today int;
  sent_total int;
  last_sent timestamptz;
  send_at timestamptz;
begin
  if exists (select 1 from public.profiles where id = new.sender and is_bot) then return new; end if;
  select case when m.user_a = new.sender then m.user_b else m.user_a end
    into other from public.matches m where m.id = new.match_id;
  select * into bot from public.profiles where id = other and is_bot and not blocked;
  if not found then return new; end if;
  if exists (select 1 from public.bot_stopped where match_id = new.match_id) then return new; end if;
  select * into s from public.bot_settings where id = 1;
  select name into member_name from public.profiles where id = new.sender;
  select count(*) filter (where created_at > now() - interval '1 day'), count(*), max(created_at)
    into sent_today, sent_total, last_sent
    from public.messages where match_id = new.match_id and sender = other;

  d := public.bot_decide(bot, new.body, member_name);
  if (d->>'stops')::boolean then
    insert into public.bot_stopped (match_id) values (new.match_id) on conflict do nothing;
  elsif d->>'intent' <> 'safety' then
    if sent_today >= s.per_day then return new; end if;
    if sent_total >= s.handoff then
      -- One closing line, then the bot goes quiet in this chat.
      d := jsonb_set(d, '{reply}', to_jsonb(coalesce(s.handoff_text->>(d->>'lang'), s.handoff_text->>'English')));
      insert into public.bot_stopped (match_id) values (new.match_id) on conflict do nothing;
    end if;
  end if;
  if d->>'reply' is null then return new; end if;
  if d->>'intent' = 'fallback' then
    -- Kept (without who asked) so the team can teach it.
    insert into public.bot_unanswered (message, lang) values (left(trim(new.body), 200), d->>'lang')
    on conflict (message) do update set times = public.bot_unanswered.times + 1, last_at = now();
  end if;
  send_at := greatest(now() + make_interval(secs => (d->>'delay')::int),
                      coalesce(last_sent, now()) + make_interval(secs => s.cool_seconds));
  insert into public.bot_pending_replies (match_id, bot_id, user_id, reply_body, scheduled_at)
  values (new.match_id, other, new.sender, d->>'reply', send_at)
  on conflict (match_id) do update
    set reply_body = excluded.reply_body, scheduled_at = excluded.scheduled_at;
  return new;
end $$;

-- A like: the bot likes back after the admin's delay (about two in three
-- times, so not every bot matches). A note sent with the like becomes the
-- first message and gets answered; otherwise the bot waits for the member
-- to say something first. Bots never start conversations.
create or replace function public.bot_accept_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  bot public.profiles;
  s public.bot_settings;
  delay int;
begin
  select * into bot from public.profiles where id = new.to_user and is_bot and not blocked;
  if not found then return new; end if;
  if exists (select 1 from public.profiles where id = new.from_user and is_bot) then return new; end if;
  if exists (select 1 from public.matches
              where user_a = least(new.from_user, new.to_user)
                and user_b = greatest(new.from_user, new.to_user)) then return new; end if;
  if coalesce(new.comment, '') = '' and random() > 0.65 then return new; end if;
  select * into s from public.bot_settings where id = 1;
  delay := s.min_delay + floor(random() * (greatest(s.max_delay, s.min_delay) - s.min_delay + 1))::int;
  insert into public.bot_pending_matches (bot_id, user_id, comment, scheduled_at)
  values (new.to_user, new.from_user, new.comment, now() + make_interval(secs => delay))
  on conflict (bot_id, user_id) do update
    set comment = coalesce(excluded.comment, bot_pending_matches.comment),
        scheduled_at = least(bot_pending_matches.scheduled_at, excluded.scheduled_at);
  return new;
end $$;

create or replace function public.process_due_bot_matches()
returns void language plpgsql security definer set search_path = public as $$
declare
  pm record;
  mid uuid;
begin
  for pm in
    delete from public.bot_pending_matches
     where id in (select id from public.bot_pending_matches where scheduled_at <= now() for update skip locked)
     returning *
  loop
    if not exists (select 1 from public.profiles where id = pm.bot_id and is_bot and not blocked) then continue; end if;
    insert into public.likes (from_user, to_user, target) values (pm.bot_id, pm.user_id, 'profile')
    on conflict do nothing;
    select id into mid from public.matches
     where user_a = least(pm.user_id, pm.bot_id) and user_b = greatest(pm.user_id, pm.bot_id);
    if mid is not null and coalesce(pm.comment, '') <> ''
       and not exists (select 1 from public.messages where match_id = mid) then
      -- Their note is the first message; messages_bot_answer queues the reply.
      insert into public.messages (match_id, sender, body) values (mid, pm.user_id, left(pm.comment, 2000));
    end if;
  end loop;
end $$;

-- Bots are labelled in the app again (undoes 019_remove_sample_profile_labels).
create or replace function public.sample_profile_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where is_bot
$$;

-- ---------------------------------------------------------------------------
-- Admin (permission 'bots').
-- ---------------------------------------------------------------------------
create or replace function public.admin_bot_training()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  return jsonb_build_object(
    'settings', (select to_jsonb(s) from public.bot_settings s where id = 1),
    'kb', (select coalesce(jsonb_agg(to_jsonb(k) order by k.position, k.intent), '[]') from public.bot_kb k),
    'unanswered', (select coalesce(jsonb_agg(to_jsonb(u) order by u.last_at desc), '[]')
                     from (select * from public.bot_unanswered order by last_at desc limit 100) u),
    'stats', jsonb_build_object(
      'pending_replies', (select count(*) from public.bot_pending_replies),
      'pending_matches', (select count(*) from public.bot_pending_matches),
      'stopped', (select count(*) from public.bot_stopped),
      'replies_today', (select count(*) from public.messages m join public.profiles p on p.id = m.sender
                         where p.is_bot and m.created_at > now() - interval '1 day')));
end $$;

-- item: {intent, position, triggers:{lang:text}, replies:{lang:text}, enabled, priority}
create or replace function public.admin_save_bot_kb(item jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  k text := lower(trim(item->>'intent'));
begin
  perform public.require_admin('bots');
  insert into public.bot_kb (intent, position, triggers, replies, enabled, priority)
  values (k, coalesce((item->>'position')::int, 100), coalesce(item->'triggers', '{}'),
          coalesce(item->'replies', '{}'), coalesce((item->>'enabled')::boolean, true),
          coalesce((item->>'priority')::boolean, false))
  on conflict (intent) do update
    set position = excluded.position, triggers = excluded.triggers, replies = excluded.replies,
        -- protected intents can be edited but stay on
        enabled = case when public.bot_kb.protected then true else excluded.enabled end,
        priority = case when public.bot_kb.protected then public.bot_kb.priority else excluded.priority end,
        updated_at = now();
  delete from public.bot_unanswered u
   where exists (select 1 from jsonb_each_text(coalesce(item->'triggers', '{}')) t
                  where position(lower(u.message) in lower(t.value)) > 0);
  perform public.log_admin('bot_kb', null, jsonb_build_object('intent', k));
end $$;

create or replace function public.admin_delete_bot_kb(p_intent text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  if exists (select 1 from public.bot_kb where intent = p_intent and protected) then
    raise exception 'this intent is built in and can’t be deleted';
  end if;
  delete from public.bot_kb where intent = p_intent;
  perform public.log_admin('bot_kb_delete', null, jsonb_build_object('intent', p_intent));
end $$;

create or replace function public.admin_save_bot_settings(item jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  update public.bot_settings set
    min_delay = coalesce((item->>'min_delay')::int, min_delay),
    max_delay = coalesce((item->>'max_delay')::int, max_delay),
    cool_seconds = coalesce((item->>'cool_seconds')::int, cool_seconds),
    from_hour = coalesce((item->>'from_hour')::int, from_hour),
    to_hour = coalesce((item->>'to_hour')::int, to_hour),
    quiet = coalesce((item->>'quiet')::boolean, quiet),
    per_day = coalesce((item->>'per_day')::int, per_day),
    handoff = coalesce((item->>'handoff')::int, handoff),
    mirror = coalesce((item->>'mirror')::boolean, mirror),
    default_lang = coalesce(item->>'default_lang', default_lang),
    threshold = coalesce((item->>'threshold')::int, threshold),
    use_name = coalesce((item->>'use_name')::boolean, use_name),
    use_emoji = coalesce((item->>'use_emoji')::boolean, use_emoji),
    away = coalesce(item->'away', away),
    handoff_text = coalesce(item->'handoff_text', handoff_text),
    updated_at = now()
  where id = 1;
  if (select min_delay > max_delay from public.bot_settings where id = 1) then
    raise exception 'the minimum delay can’t be more than the maximum';
  end if;
  perform public.log_admin('bot_settings', null, '{}');
end $$;

-- The panel's training chat and tests: what a bot would say, without
-- sending anything. [bot_id] null picks any live bot.
create or replace function public.admin_bot_try(message text, bot_id uuid default null, lang text default null,
                                                at_hour int default null, member_name text default 'Rohan')
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  bot public.profiles;
  d jsonb;
begin
  perform public.require_admin('bots');
  select * into bot from public.profiles where id = coalesce(bot_id, id) and is_bot order by random() limit 1;
  if not found then raise exception 'make a bot first'; end if;
  d := public.bot_decide(bot, message, member_name, at_hour, nullif(lang, 'Auto'));
  if d->>'intent' = 'fallback' then
    insert into public.bot_unanswered (message, lang) values (left(trim(message), 200), d->>'lang')
    on conflict (message) do update set times = public.bot_unanswered.times + 1, last_at = now();
  end if;
  return d || jsonb_build_object('bot', bot.name, 'bot_id', bot.id);
end $$;

create or replace function public.admin_clear_unanswered(msg text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  delete from public.bot_unanswered where msg is null or message = msg;
end $$;

revoke all on function public.bot_detect_lang(text) from public, anon, authenticated;
revoke all on function public.bot_match_intent(text, text) from public, anon, authenticated;
revoke all on function public.bot_compose(public.profiles, text, text, text) from public, anon, authenticated;
revoke all on function public.bot_decide(public.profiles, text, text, int, text) from public, anon, authenticated;
revoke all on function public.admin_bot_training() from public, anon;
revoke all on function public.admin_save_bot_kb(jsonb) from public, anon;
revoke all on function public.admin_delete_bot_kb(text) from public, anon;
revoke all on function public.admin_save_bot_settings(jsonb) from public, anon;
revoke all on function public.admin_bot_try(text, uuid, text, int, text) from public, anon;
revoke all on function public.admin_clear_unanswered(text) from public, anon;
grant execute on function public.admin_bot_training() to authenticated;
grant execute on function public.admin_save_bot_kb(jsonb) to authenticated;
grant execute on function public.admin_delete_bot_kb(text) to authenticated;
grant execute on function public.admin_save_bot_settings(jsonb) to authenticated;
grant execute on function public.admin_bot_try(text, uuid, text, int, text) to authenticated;
grant execute on function public.admin_clear_unanswered(text) to authenticated;

-- Deliver due matches and replies every minute even when nobody has the
-- app open (the app also asks on its own). pg_cron is enabled on the
-- Supabase project; this is a no-op where it isn't.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.unschedule(jobid) from cron.job where jobname = 'bot-events';
    perform cron.schedule('bot-events', '* * * * *', 'select public.process_due_bot_events()');
  end if;
end $$;
