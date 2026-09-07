import 'package:sqflite/sqflite.dart';

import '../models/lesson.dart';

class SeedData {
  static Future<void> insertSeedData(Database db) async {
    for (final lesson in lessons) {
      await db.insert('lessons', lesson.toMap());
    }
  }

  static final List<Lesson> lessons = [
    Lesson(
      grade: 'Grade 1',
      subject: 'Foundational Numeracy',
      topic: 'Counting 1–10',
      learningOutcome: 'Child can count objects from 1 to 10.',
      hindiInstruction: 'बच्चों को दस वस्तुएँ दें और उन्हें एक-एक करके गिनने के लिए कहें।',
      santaliTranslation:
          'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱜᱮᱞ ᱜᱚᱴᱟᱝ ᱡᱤᱱᱤᱥ ᱮᱢᱟ ᱠᱚᱢ ᱟᱨ ᱢᱤᱫ-ᱢᱤᱫ ᱛᱮ ᱞᱮᱠᱷᱟ ᱪᱚ ᱠᱚᱢ᱾',
      isPrototypeTranslation: true,
    ),
    Lesson(
      grade: 'Grade 1',
      subject: 'Foundational Literacy',
      topic: 'Letter Recognition',
      learningOutcome: 'Child can recognize and pronounce letters.',
      hindiInstruction: 'बच्चों को अपनी किताब खोलने के लिए कहें।',
      santaliTranslation:
          'ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱟᱠᱚᱣᱟᱜ ᱯᱚᱛᱚᱵ ᱠᱷᱩᱞᱟᱹᱣ ᱞᱟᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      isPrototypeTranslation: true,
    ),
    Lesson(
      grade: 'Grade 1',
      subject: 'Foundational Numeracy',
      topic: 'Addition 1-5',
      learningOutcome: 'Child can add numbers up to 5.',
      hindiInstruction: 'दो और दो कितने होते हैं, बच्चों से पूछें।',
      santaliTranslation:
          'ᱵᱟᱨ ᱟᱨ ᱵᱟᱨ ᱛᱤᱱᱟᱹᱜ ᱦᱩᱭᱩᱜᱼᱟ, ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱠᱩᱞᱤ ᱠᱚᱢ᱾',
      isPrototypeTranslation: true,
    ),
    Lesson(
      grade: 'Grade 1',
      subject: 'Foundational Literacy',
      topic: 'Listening and Speaking',
      learningOutcome: 'Child can listen and repeat a short sentence.',
      hindiInstruction: 'एक वाक्य बोलें और बच्चों से दोहराने को कहें।',
      santaliTranslation:
          'ᱢᱤᱫ ᱟᱹᱭᱠᱟᱹᱣ ᱢᱮ ᱟᱨ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱫᱩᱦᱲᱟᱹ ᱞᱟᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      isPrototypeTranslation: true,
    ),
    Lesson(
      grade: 'Grade 2',
      subject: 'Foundational Numeracy',
      topic: 'Place Value',
      learningOutcome: 'Child can identify tens and ones.',
      hindiInstruction: 'दस और एक की जगह समझाने के लिए मोतियों का उपयोग करें।',
      santaliTranslation:
          'ᱜᱮᱞ ᱟᱨ ᱢᱤᱫ ᱡᱟᱭᱜᱟ ᱵᱩᱡᱷᱟᱹᱣ ᱞᱟᱜᱤᱫ ᱢᱚᱱᱤ ᱵᱮᱵᱷᱟᱨ ᱢᱮ᱾',
      isPrototypeTranslation: true,
    ),
    Lesson(
      grade: 'Grade 2',
      subject: 'Foundational Literacy',
      topic: 'Simple Words',
      learningOutcome: 'Child can read two-letter words.',
      hindiInstruction: 'बोर्ड पर सरल शब्द लिखें और बच्चों से पढ़ने को कहें।',
      santaliTranslation:
          'ᱵᱚᱨᱰ ᱨᱮ ᱟᱞᱜᱟ ᱟᱹᱲᱟᱹ ᱚᱞ ᱢᱮ ᱟᱨ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱯᱟᱲᱦᱟᱣ ᱞᱟᱜᱤᱫ ᱢᱮᱛᱟ ᱠᱚᱢ᱾',
      isPrototypeTranslation: true,
    ),
  ];
}
