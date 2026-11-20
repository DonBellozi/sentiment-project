package ru.mifi;
import java.util.*;
/** Educational lexical baseline. No trained ML model is claimed. */
public final class Sentiment {
 private static final Set<String> POS=Set.of("good","great","love","excellent","happy","hello","хорошо","отлично","люблю","прекрасно");
 private static final Set<String> NEG=Set.of("bad","terrible","hate","awful","sad","плохо","ужасно","ненавижу");
 public static String analyze(String text) {
  int score=0;
  for(String word:text.toLowerCase(Locale.ROOT).split("[^\\p{L}]+")) {
   if(POS.contains(word))score++;
   if(NEG.contains(word))score--;
  }
  return score>0 ? "positive" : score<0 ? "negative" : "neutral";
 }
}
