import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';
import 'edge_tts_service.dart';
import 'groq_stt_service.dart';
import 'local_stt_service.dart';

enum VoiceState { idle, speaking, listening, processing }

class VoiceService {
  static final FlutterTts _tts = FlutterTts();

  static VoiceState _state = VoiceState.idle;
  static void Function(VoiceState)? onStateChanged;
  static List<Map<String, String>> _hebrewVoices = [];
  static Map<String, String>? _selectedVoice;

  static VoiceState get state => _state;
  static List<Map<String, String>> get hebrewVoices => _hebrewVoices;
  static Map<String, String>? get selectedVoice => _selectedVoice;

  /// User preference: read questions aloud automatically (persisted).
  static Future<bool> getVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('voice_enabled') ?? true;
  }

  static Future<void> setVoiceEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_enabled', v);
  }

  static Future<void> init() async {
    // Load the user's saved speech rate before any synthesis.
    await EdgeTtsService.loadRate();
    // Warm up the local ivrit-ai transcription server (no-op if not installed)
    LocalSttService.ensureServer();
    // Warm up the Edge neural TTS sidecar (no-op if Python is missing)
    EdgeTtsService.ensureServer();

    await _tts.setLanguage('he-IL');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    try {
      final rawVoices = await _tts.getVoices;
      final all = (rawVoices as List?)?.cast<Map>() ?? [];
      _hebrewVoices = all
          .where((v) => (v['locale'] as String? ?? '').toLowerCase().startsWith('he'))
          .map((v) => {'name': v['name'] as String, 'locale': v['locale'] as String})
          .toList();
      if (_hebrewVoices.isNotEmpty) {
        await _applyVoice(_hebrewVoices.first);
      }
    } catch (_) {}

    _tts.setStartHandler(() => _setState(VoiceState.speaking));
    _tts.setCompletionHandler(() => _setState(VoiceState.idle));
    _tts.setCancelHandler(() => _setState(VoiceState.idle));
    _tts.setErrorHandler((_) => _setState(VoiceState.idle));

    EdgeTtsService.onStart = () => _setState(VoiceState.speaking);
    EdgeTtsService.onComplete = () => _setState(VoiceState.idle);
  }

  /// TTS-only word fixes for terms Avri mispronounces (user-approved list).
  /// The on-screen text is never changed.
  static String _fixPronunciation(String text) {
    // TTS-only replacements, user-approved. Flat statements (a single
    // ~250-call chain crashes the Dart compiler with OOM).
    var t = text;
    // Colon reads as the word "נקודתיים"; turn it into a sentence pause.
    t = t.replaceAll(':', '.');
    t = t.replaceAll('קמ"ש', 'קילומטר לשעה');
    t = t.replaceAll('קמ״ש', 'קילומטר לשעה');
    t = t.replaceAll('זכות הקדימה', 'העדיפות');
    t = t.replaceAll('זכות-קדימה', 'עדיפות');
    t = t.replaceAll('זכות קדימה', 'עדיפות');
    t = t.replaceAll('מהבהב', 'מבזיק');
    t = t.replaceAll(RegExp(r'אי?-בי-אס\s*\(ABS\)'), 'ABS');
    t = t.replaceAll(RegExp(r"\(?ג'י-פי-אס\s*[-–,]?\s*GPS\)?"), 'GPS');
    t = t.replaceAll("ג'י-פי-אס", 'GPS');
    t = t.replaceAll('לרגע קט', 'לרגע');
    t = t.replaceAll('החלה על', 'המוטלת על');
    t = t.replaceAll('ק"ג', 'קילוגרם');
    t = t.replaceAll('ק״ג', 'קילוגרם');
    t = t.replaceAll('בק"מ', 'בקילומטרים');
    t = t.replaceAll('בק״מ', 'בקילומטרים');
    t = t.replaceAll('ק"מ', 'קילומטרים');
    t = t.replaceAll('ק״מ', 'קילומטרים');
    t = t.replaceAll('והיכון', 'וְהִכּוֹן');
    t = t.replaceAll('היכון', 'הִכּוֹן');
    t = t.replaceAll('עקלתון', 'מתפתלת');
    t = t.replaceAll(RegExp(r'(?<![א-ת])אתת(?![א-ת])'), 'אותת');
    t = t.replaceAll('(starter)', '');
    t = t.replaceAll('בדיקת שכרות', 'בדיקת אלכוהול');
    t = t.replaceAll('כנוהג בשכרות', 'כנהג שיכור');
    t = t.replaceAll('לשאלת שכרותו', 'לשאלה אם הוא שיכור');
    t = t.replaceAll('ייחשב', 'יֵחָשֵׁב');
    t = t.replaceAll('לבלאי', 'לִבְּלַאי');
    t = t.replaceAll('ובלאי', 'וּבְלַאי');
    t = t.replaceAll('בלאי', 'בְּלַאי');
    t = t.replaceAll('משכרים', 'אלכוהוליים');
    t = t.replaceAll('משכר', 'אלכוהולי');
    t = t.replaceAll("א' (A)", 'אָלֶף');
    t = t.replaceAll("ב' (B)", 'בית');
    t = t.replaceAll("ג' (C)", 'גימל');
    t = t.replaceAll('מחווני הכיוון', 'אורות האיתות');
    t = t.replaceAll('מחווני המצוקה', 'אורות המצוקה');
    t = t.replaceAll('מחווני כיוון', 'אורות איתות');
    t = t.replaceAll('מחוון הכיוון', 'אור האיתות');
    t = t.replaceAll('לוח המחוונים', 'לוח השעונים');
    t = t.replaceAll('במחוונים', 'בלוח השעונים');
    t = t.replaceAll('סינוור', 'עיוורון');
    t = t.replaceAll('ערנות', 'עֵרָנוּת');
    t = t.replaceAll('שהראות לקויה', 'שתנאי הראייה לקויים');
    t = t.replaceAll('הראות לקויה', 'תנאי הראייה לקויים');
    t = t.replaceAll('כשהראות', 'כְּשֶׁהָרְאוּת');
    t = t.replaceAll('שהראות בה מוגבלת', 'שתנאי הראייה בה מוגבלים');
    t = t.replaceAll('שהראות תתבהר', 'שתנאי הראייה ישתפרו');
    t = t.replaceAll('הראות מוגבלת', 'תנאי הראייה מוגבלים');
    t = t.replaceAll('תנאי הראות', 'תנאי הראייה');
    t = t.replaceAll(RegExp(r'(?<![א-ת])הראות(?![א-ת])'), 'תנאי הראייה');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ודא(?![א-ת])'), 'יש לוודא');
    t = t.replaceAll(
          'רק שצורת הסוליה של הצמיג (פני הצמיג) החדש זהה לצורת הסוליה של הצמיג הישן',
          'רק שצורת פני הצמיג החדש זֵהָה לצורת פני הצמיג הישן');
    t = t.replaceAll(
          'רק שמידת לחץ האוויר של הצמיג החדש זהה למידת לחץ האוויר של הצמיג הישן',
          'רק שכמות האוויר של הצמיג החדש זֵהָה לכמות האוויר של הצמיג הישן');
    t = t.replaceAll('לחץ אוויר נמוך', 'כמות אוויר נמוכה');
    t = t.replaceAll('לחץ אוויר גבוה', 'כמות אוויר גבוהה');
    t = t.replaceAll('לחץ האוויר הנחוץ', 'כמות האוויר הנחוצה');
    t = t.replaceAll('לחץ האוויר בצמיגים גבוה', 'כמות האוויר בצמיגים גבוהה');
    t = t.replaceAll('לחץ האוויר במערכת הבלמים יורד', 'כמות האוויר במערכת הבלמים יורדת');
    t = t.replaceAll('לחץ האוויר', 'כמות האוויר');
    t = t.replaceAll('לחץ אוויר', 'כמות אוויר');
    t = t.replaceAll('בצמיגים', 'בַּצְּמִיגִים');
    t = t.replaceAll('בדוק במראות', 'הסתכל במראות');
    t = t.replaceAll('בדוק את מצב התנועה', 'הסתכל על מצב התנועה');
    t = t.replaceAll(RegExp(r'(?<![א-ת])עקוב(?![א-ת])'), 'עֲקוֹב');
    t = t.replaceAll(RegExp(r'(?<![א-ת])עזר(?![א-ת])'), 'עֵזֶר');
    t = t.replaceAll(RegExp(r'(?<![א-ת])לעתים(?![א-ת])'), 'לעיתים');
    t = t.replaceAll(RegExp(r'(?<![א-ת])והאץ(?![א-ת])'), 'וְהָאֵץ');
    t = t.replaceAll(RegExp(r'(?<![א-ת])האץ(?![א-ת])'), 'הָאֵץ');
    t = t.replaceAll('מטפה', 'מטף');
    t = t.replaceAll('אורכו', 'אֹרְכּוֹ');
    t = t.replaceAll('אורכה', 'אֹרְכָּהּ');
    t = t.replaceAll('חשכה', 'חֲשֵׁכָה');
    t = t.replaceAll('פתחי האוורור', 'פִּתְחֵי זרימת האוויר');
    t = t.replaceAll('צריכה להיות מערכת אוורור', 'צריכים להיות פִּתְחֵי אוויר');
    t = t.replaceAll('אוורור חזק', 'זרימת אוויר חזקה');
    t = t.replaceAll('חוסר אוורור מספיק', 'חוסר זרימת אוויר מספקת');
    t = t.replaceAll('חוסר אוורור', 'חוסר זרימת אוויר');
    t = t.replaceAll('בעל ידע וניסיון', 'בעל הבנה וניסיון');
    t = t.replaceAll('בעוברך', 'כשאתה עובר');
    t = t.replaceAll(RegExp(r'(?<![א-ת])עוברך(?![א-ת])'), 'שאתה עובר');
    t = t.replaceAll('למסילה', 'לַמְּסִלָּה');
    t = t.replaceAll('בלימות', 'בְּלִימוֹת');
    t = t.replaceAll('הגבר את', 'הַעֲלֵה את');
    t = t.replaceAll('בחניית הנכים', 'בחנייה לאנשים עם מוגבלויות');
    t = t.replaceAll('עגלת הנכים', 'כיסא הגלגלים');
    t = t.replaceAll('דיסקת', 'דיסקית');
    t = t.replaceAll('פתח חלון', 'פְּתַח חלון');
    t = t.replaceAll('רעשים', 'רְעָשִׁים');
    t = t.replaceAll('צליפת שוט', 'מַכַּת שוט');
    t = t.replaceAll(RegExp(r'(?<![א-ת])יטה(?![א-ת])'), 'יסיט');
    t = t.replaceAll('הצדה', 'לצד');
    t = t.replaceAll('והאזן', 'ושים לב');
    t = t.replaceAll('רכבת', 'רַכֶּבֶת');
    t = t.replaceAll('להגה קל להפעלה', 'למערכת היגוי קלה להפעלה');
    t = t.replaceAll('והמתן', 'ותמתין');
    t = t.replaceAll(RegExp(r'(?<![א-ת])המתן(?![א-ת])'), 'תמתין');
    t = t.replaceAll('מערכת השמע', 'מערכת הרדיו');
    t = t.replaceAll('משלבים', 'מְשַׁלְּבִים');
    t = t.replaceAll('כדי שייטיב לראות', 'כדי לראות טוב יותר');
    t = t.replaceAll('המאטה את', 'הבולמת את');
    t = t.replaceAll('מחייב האטה', 'מחייב הפחתת מהירות');
    t = t.replaceAll('לצורכי', 'לְצָרְכֵי');
    t = t.replaceAll('שלמות', 'שְׁלֵמוּת');
    t = t.replaceAll('לנתיבך', 'לנתיב שלך');
    t = t.replaceAll(RegExp(r'(?<![א-ת])חצים(?![א-ת])'), 'חִצִּים');
    t = t.replaceAll('עמעום', 'הנמכת');
    t = t.replaceAll('רעשני', 'רועש');
    t = t.replaceAll('שמאליים', 'שְׂמָאלִיִּים');
    t = t.replaceAll('מכולת האשפה', 'המכולה');
    t = t.replaceAll('ויסתכנו בפגיעה', 'ויהיו בסכנת פגיעה');
    t = t.replaceAll('והזהר', 'והיזהר');
    t = t.replaceAll(RegExp(r'(?<![א-ת])יחצו(?![א-ת])'), 'יעברו');
    t = t.replaceAll('אין ביכולתן', 'אין להן אפשרות');
    t = t.replaceAll('בלם העזר', 'בלם החנייה');
    t = t.replaceAll('הראייה (ראות ונראות)', 'הראייה');
    t = t.replaceAll('לנכה', 'לנָכֶה');
    t = t.replaceAll('הנכה', 'הנָכֶה');
    t = t.replaceAll(RegExp(r'(?<![א-ת])נכה(?![א-ת])'), 'נָכֶה');
    t = t.replaceAll('שלגביו אין תמרור', 'שאין לו תמרור');
    t = t.replaceAll('בתמרור', 'בְּתַמְרוּר');
    t = t.replaceAll('תמרור', 'תַמְרוּר');
    t = t.replaceAll('המונע במנוע', 'המוּנָע במנוע');
    t = t.replaceAll('מתקן ברכב המונע את', 'מערכת ברכב שֶׁמּוֹנַעַת את');
    t = t.replaceAll('המונע את', 'המוֹנֵעַ את');
    t = t.replaceAll('המונעים ממנו', 'שבגללם אין לו');
    t = t.replaceAll('בהחניית', 'בעת חניית');
    t = t.replaceAll('במגרש חנייה מקורה', 'בחניון סגור');
    t = t.replaceAll('מחנייה מקורה', 'מחניון סגור');
    t = t.replaceAll('להמתנה לבוא הנוסעים', 'להמתנה לנוסעים');
    t = t.replaceAll('עד לבואו של', 'עד שיגיע');
    t = t.replaceAll('ולהמתין לבואם', 'ולהמתין עד שיגיעו');
    t = t.replaceAll('וימתין לבוא הבוחן', 'וימתין עד שיגיע הבוחן');
    t = t.replaceAll('ויחכה לבוא השוטר', 'ויחכה עד שיגיע השוטר');
    t = t.replaceAll('עלול לבוא רכב', 'עלול להגיע רכב');
    t = t.replaceAll('עד לבוא כוחות', 'עד שיגיעו כוחות');
    t = t.replaceAll('עד לבוא שוטר', 'עד שיגיע שוטר');
    t = t.replaceAll('וצפור', 'והשתמש בצופר');
    t = t.replaceAll(RegExp(r'(?<![א-ת])צפור(?![א-ת])'), 'השתמש בצופר');
    t = t.replaceAll('לכוונון המושב', 'להתאמת זווית המושב');
    t = t.replaceAll('לכוונון', 'להתאמת');
    t = t.replaceAll('ובהתאם', 'וּבְהֶתְאֵם');
    t = t.replaceAll('יימין לשפת', 'ייצמד לשפת');
    t = t.replaceAll(RegExp(r'(?<![א-ת])יימין(?![א-ת])'), 'ייצמד לימין');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ופנס(?![א-ת])'), 'ופָּנָס');
    t = t.replaceAll(RegExp(r'(?<![א-ת])הפנס(?![א-ת])'), 'הפָּנָס');
    t = t.replaceAll(RegExp(r'(?<![א-ת])בפנס(?![א-ת])'), 'בפָּנָס');
    t = t.replaceAll(RegExp(r'(?<![א-ת])לפנס(?![א-ת])'), 'לפָּנָס');
    t = t.replaceAll(RegExp(r'(?<![א-ת])פנס(?![א-ת])'), 'פָּנָס');
    t = t.replaceAll(RegExp(r'(?<![א-ת])לחנות(?![א-ת])'), 'לַחֲנוֹת');
    t = t.replaceAll('לזמן', 'לִזְמַן');
    t = t.replaceAll(RegExp(r'(?<![א-ת])זמן(?![א-ת])'), 'זְמַן');
    t = t.replaceAll('ממולך', 'ממול');
    t = t.replaceAll('שגובהו', 'שהגובה שלו');
    t = t.replaceAll('המרומזר', 'עם הרמזור');
    t = t.replaceAll('מרומזר', 'עם רמזור');
    t = t.replaceAll('בתאונת', 'בְּתְאוּנַת');
    t = t.replaceAll('בתאונה', 'בְּתְאוּנָה');
    t = t.replaceAll('תאונות', 'תְּאוּנוֹת');
    t = t.replaceAll('תאונת', 'תְּאוּנַת');
    t = t.replaceAll('תאונה', 'תְּאוּנָה');
    t = t.replaceAll('צומת', 'צֹמֶת');
    t = t.replaceAll('בהתקרבך', 'כשאתה מתקרב');
    t = t.replaceAll('מתומרר', 'מסומן בתמרורים');
    t = t.replaceAll('כדי שלא יסונוור', 'כדי שהאור לא יפגע בראייה');
    t = t.replaceAll('המסנוור', 'הפוגע בראייה');
    t = t.replaceAll('ומסנוור', 'ופוגע בראייה');
    t = t.replaceAll('מסנוורת', 'פוגעת בראייה');
    t = t.replaceAll('מסנוור', 'פוגע בראייה');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ובכל(?![א-ת])'), 'וּבְכֹל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])בכל(?![א-ת])'), 'בְּכֹל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])לכל(?![א-ת])'), 'לְכֹל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])וכל(?![א-ת])'), 'וְכֹל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ככל(?![א-ת])'), 'כְּכֹל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])שכל(?![א-ת])'), 'שֶׁכֹּל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])מכל(?! הדלק)(?![א-ת])'), 'מִכֹּל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])כל(?![א-ת])'), 'כֹּל');
    t = t.replaceAll('נהגים', 'נֶהָגִים');
    t = t.replaceAll('השעונים', 'הַשְּׁעוֹנִים');
    t = t.replaceAll('יסטה', 'יִסְטֶה');
    t = t.replaceAll(RegExp(r'מעגל(?!ה)'), 'מַעֲגַל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])באטיות(?![א-ת])'), 'באיטיות');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ואטית(?![א-ת])'), 'ואיטית');
    t = t.replaceAll(RegExp(r'(?<![א-ת])האטי(?![א-ת])'), 'האיטי');
    t = t.replaceAll(RegExp(r'(?<![א-ת])אטית(?![א-ת])'), 'איטית');
    t = t.replaceAll(RegExp(r'(?<![א-ת])אטי(?![א-ת])'), 'איטי');
    t = t.replaceAll('חגורות מותניים', 'חגורות אגן');
    t = t.replaceAll('חגורת מותניים', 'חגורת אגן');
    t = t.replaceAll(RegExp(r'(?<![א-ת])והבט(?![א-ת])'), 'והסתכל');
    t = t.replaceAll(RegExp(r'(?<![א-ת])הבט(?![א-ת])'), 'הסתכל');
    t = t.replaceAll('והדלק את', 'והפעל את');
    t = t.replaceAll('הדלק את', 'הפעל את');
    t = t.replaceAll('הדלק אורות', 'הפעל אורות');
    t = t.replaceAll('ולהימין', 'ולהיצמד לימין');
    t = t.replaceAll('להימין', 'להיצמד לימין');
    t = t.replaceAll('להיצמד', 'לְהִיצָּמֵד');
    t = t.replaceAll('והיצמד', 'וְהִיצָּמֵד');
    t = t.replaceAll(RegExp(r'(?<![א-ת])היצמד(?![א-ת])'), 'הִיצָּמֵד');
    t = t.replaceAll('אורות החזית', 'האורות הקדמיים');
    t = t.replaceAll('אור החזית', 'האור הקדמי');
    t = t.replaceAll('פנסי החזית', 'הפנסים הקדמיים');
    t = t.replaceAll('פנסי חזית', 'פנסים קדמיים');
    t = t.replaceAll('בחזית הרכב', 'בקדמת הרכב');
    t = t.replaceAll('מחזית הרכב', 'מקדמת הרכב');
    t = t.replaceAll('פגיעת חזית-אחור', 'התנגשות ברכב שמלפנים');
    t = t.replaceAll('חזיתית', 'קדמית');
    t = t.replaceAll(RegExp(r'(?<![א-ת])השלט(?![א-ת])'), 'השילוט');
    t = t.replaceAll(RegExp(r'(?<![א-ת])בשלט(?![א-ת])'), 'בשילוט');
    t = t.replaceAll(RegExp(r'(?<![א-ת])שלט(?![א-ת])'), 'שילוט');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ושמור על'), 'והקפד על');
    t = t.replaceAll(RegExp(r'(?<![א-ת])שמור על'), 'הקפד על');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ושמור מרחק'), 'והקפד על מרחק');
    t = t.replaceAll(RegExp(r'(?<![א-ת])שמור מרחק'), 'הקפד על מרחק');
    t = t.replaceAll(RegExp(r'(?<![א-ת])רכבים(?![א-ת])'), 'כלי רכב');
    t = t.replaceAll('כלי הרכב', 'כְּלֵי הרכב');
    t = t.replaceAll('כלי רכב', 'כְּלֵי רכב');
    t = t.replaceAll('ולכוון את תנועת', 'ולנהל את תנועת');
    t = t.replaceAll(RegExp(r'(?<!מ)רכב(?![א-ת])'), 'רֶכֶב');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ועצור(?![א-ת])'), 'וַעֲצוֹר');
    t = t.replaceAll(RegExp(r'(?<![א-ת])עצור(?![א-ת])'), 'עֲצוֹר');
    t = t.replaceAll('המנהליים', 'הַמִּנְהָלִיִּים');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ובה(?![א-ת])'), 'וּבָּהּ');
    t = t.replaceAll(RegExp(r'(?<![א-ת])ותן(?![א-ת])'), 'וְתֵן');
    t = t.replaceAll('הועמד', 'הושאר');
    t = t.replaceAll('מיבואן', 'מהיבואן');
    t = t.replaceAll('לרענון', 'למנוחה קצרה');
    t = t.replaceAll('תן תשומת לב מיוחדת', 'שים לב במיוחד');
    t = t.replaceAll('מתן תשומת לב מיוחדת ל', 'לשים לב במיוחד ל');
    t = t.replaceAll('צורך בתשומת לב מיוחדת', 'צורך לשים לב במיוחד');
    t = t.replaceAll('להעיר את תשומת לבו של נהג הרכב הבא מנגד',
          'לגרום לנהג הרכב הבא מנגד לשים לב');
    t = t.replaceAll('להפנות את מלוא תשומת הלב', 'לשים לב באופן מלא');
    t = t.replaceAll('להסב את תשומת לבם', 'לגרום להם לשים לב');
    t = t.replaceAll('תסב את תשומת לבו של נהג הרכב הנעקף',
          'תגרום לנהג הרכב הנעקף לשים לב');
    t = t.replaceAll('ולכוון את מושב', 'ולהתאים את מושב');
    t = t.replaceAll('לכוון את הרדיו', 'להתאים את הרדיו');
    t = t.replaceAll('יש לכוון:', 'יש להתאים:');
    t = t.replaceAll('לכוון את המראות', 'להתאים את זווית המראות');
    t = t.replaceAll('לכוון אותה', 'לשלוט בה');
    t = t.replaceAll('לאחר שהחנה את רכבו', 'לאחר חניית רכבו');
    t = t.replaceAll('וללא', 'ובלי');
    t = t.replaceAll('מימינך', 'מימין');
    t = t.replaceAll('והכשרתו', 'וההכשרה שלו');
    t = t.replaceAll(RegExp(r'(?<![א-ת])לבש(?![א-ת])'), 'לָבַשׁ');
    t = t.replaceAll('בהגיעך', 'כשאתה מגיע');
    t = t.replaceAll('ולחץ על', 'וּלְחַץ על');
    t = t.replaceAll('לחץ על', 'לְחַץ על');
    t = t.replaceAll('להמשך', 'לְהֶמְשֵׁךְ');
    t = t.replaceAll('המשך החזקת', 'הֶמְשֵׁךְ החזקת');
    t = t.replaceAll('המשך הנסיעה', 'הֶמְשֵׁךְ הנסיעה');
    t = t.replaceAll('והמשך', 'וְהַמְשֵׁךְ');
    t = t.replaceAll(RegExp(r'(?<![א-ת])המשך(?![א-ת])'), 'הַמְשֵׁךְ');
    t = t.replaceAll(RegExp(r'(?<![א-ת])והאט(?![א-ת])'), 'וְהַאֵט');
    t = t.replaceAll(RegExp(r'(?<![א-ת])האט(?![א-ת])'), 'הַאֵט');
    t = t.replaceAll('חובת ההאטה', 'חובת הפחתת המהירות');
    t = t.replaceAll('חובת האטה', 'חובת הפחתת מהירות');
    t = t.replaceAll('האטת מהירות', 'הפחתת מהירות');
    t = t.replaceAll('האטת הרכב', 'הפחתת מהירות הרכב');
    t = t.replaceAll('ולהאט', 'וּלְהַאֵט');
    t = t.replaceAll('להאטת', 'לְהַאָטַת');
    t = t.replaceAll('להאטה', 'לְהַאָטָה');
    t = t.replaceAll('להאט', 'לְהַאֵט');
    t = t.replaceAll('ההאטה', 'הַהַאָטָה');
    t = t.replaceAll('והאטות', 'וְהַאָטוֹת');
    t = t.replaceAll('והאטה', 'וְהַאָטָה');
    t = t.replaceAll('האטת', 'הַאָטַת');
    t = t.replaceAll('האטה', 'הַאָטָה');
    // עפר (afar=dirt road) vs עֹפֶר (ofer=fawn) homograph
    t = t.replaceAll('העפר', 'הֶעָפָר');
    t = t.replaceAllMapped(RegExp(r'(?<![א-ת])עפר(?![א-ת])'), (m) => 'עָפָר');
    // סלול (salul=paved) — must NOT touch מסלול (maslul=lane), a different word
    t = t.replaceAll('הסלולה', 'הַסְלוּלָה');
    t = t.replaceAll('הסלולים', 'הַסְלוּלִים');
    t = t.replaceAll('הסלול', 'הַסָּלוּל');
    t = t.replaceAll('סלולות', 'סְלוּלוֹת');
    t = t.replaceAll('סלולים', 'סְלוּלִים');
    t = t.replaceAll('סלולה', 'סְלוּלָה');
    t = t.replaceAllMapped(RegExp(r'(?<![א-ת])סלול(?![א-ת])'), (m) => 'סָלוּל');
    return t;
  }

  /// Speaks with the natural Edge neural voice (Avri); falls back to the
  /// installed Windows voice when offline.
  static Future<void> _speakText(String text) async {
    final fixed = _fixPronunciation(text);
    final ok = await EdgeTtsService.speak(fixed);
    if (!ok) {
      await _tts.speak(fixed);
    }
  }

  static Future<void> _applyVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
    _selectedVoice = voice;
  }

  static Future<void> selectVoice(Map<String, String> voice) => _applyVoice(voice);

  static void _setState(VoiceState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  static String _clean(String text) => text
      .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '')
      .replaceAll(RegExp(r'[✅❌✓✗•·]'), '')
      .replaceAll('—', ',')
      .replaceAll('–', ',')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int? _readingQuestionId;

  static String questionText(Question q) {
    // "אפשרות" instead of "תשובה" — Avri mispronounces the latter
    final labels = ['אחת', 'שתיים', 'שלוש', 'ארבע'];
    final buf = StringBuffer()
      ..write(_clean(q.text))
      ..write('. ');
    for (int i = 0; i < q.options.length; i++) {
      buf.write('אפשרות מספר ${labels[i]}, ${_clean(q.options[i])}. ');
    }
    return buf.toString();
  }

  /// Synthesizes the question audio ahead of time for instant playback.
  static void prefetchQuestion(Question q) =>
      EdgeTtsService.prefetch(_fixPronunciation(questionText(q)));

  static Future<void> readQuestion(Question q) async {
    // Already reading this exact question — ignore the duplicate request
    if (_readingQuestionId == q.id &&
        (_state == VoiceState.speaking || EdgeTtsService.isBusy)) {
      return;
    }
    _readingQuestionId = q.id;
    await stop();
    await _speakText(questionText(q));
    if (_readingQuestionId == q.id) _readingQuestionId = null;
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    await EdgeTtsService.stop();
    await _speakText(_clean(text));
  }

  /// Local ivrit-ai engine (whisper.cpp) when installed; Groq otherwise.
  static bool get _useLocal => LocalSttService.isAvailable;

  /// Checks the registry for an active capture device. Recording with no
  /// microphone crashes the Windows Media Foundation plugin, so we must
  /// verify before ever touching the recorder.
  static Future<bool> micAvailable() async {
    try {
      final r = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture',
        '/s', '/v', 'DeviceState',
      ]).timeout(const Duration(seconds: 5));
      final out = (r.stdout as String);
      return RegExp(r'DeviceState\s+REG_DWORD\s+0x1\b').hasMatch(out);
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    await _tts.stop();
    await EdgeTtsService.stop();
    await GroqSttService.cancel();
    await LocalSttService.cancel();
    _setState(VoiceState.idle);
  }

  /// Tap once to start recording; recording auto-stops after 5 seconds
  /// (or when stopListening is called) and is transcribed.
  static Future<void> startListening({
    required void Function(int answerIndex) onResult,
  }) async {
    if (_state == VoiceState.listening || _state == VoiceState.processing) return;
    if (!await micAvailable()) return;
    await _tts.stop();
    await EdgeTtsService.stop();

    if (_useLocal) {
      if (!await LocalSttService.hasPermission) return;
      _setState(VoiceState.listening);
      await LocalSttService.startRecording();
    } else {
      if (!await GroqSttService.hasPermission) return;
      _setState(VoiceState.listening);
      await GroqSttService.startRecording();
    }

    await Future.delayed(const Duration(seconds: 5));
    if (_state != VoiceState.listening) return;
    await _finishListening(onResult);
  }

  static Future<void> _finishListening(void Function(int) onResult) async {
    _setState(VoiceState.processing);
    String? text;
    if (_useLocal) {
      text = await LocalSttService.stopAndTranscribe();
      // Local engine failed — try Groq with nothing to lose? The recording
      // was consumed locally, so just report idle and let the user retry.
    } else {
      text = await GroqSttService.stopAndTranscribe();
    }
    _setState(VoiceState.idle);
    if (text != null) {
      final index = _parseAnswer(text);
      if (index != null) onResult(index);
    }
  }

  static Future<void> stopListening() async {
    if (_state != VoiceState.listening) return;
    await GroqSttService.cancel();
    await LocalSttService.cancel();
    _setState(VoiceState.idle);
  }

  static int? _parseAnswer(String words) {
    final w = words.trim().toLowerCase();
    if (w.contains('אחד') || w.contains('אחת') || w.contains('1')) return 0;
    if (w.contains('שתיים') || w.contains('שניים') || w.contains('שתים') || w.contains('2')) {
      return 1;
    }
    if (w.contains('שלוש') || w.contains('3')) return 2;
    if (w.contains('ארבע') || w.contains('4')) return 3;
    return null;
  }
}
