package ru.mifi;
import java.util.Map;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
@RestController
public class SentimentController {
 private final MeterRegistry registry;
 public SentimentController(MeterRegistry registry){this.registry=registry;}
 @GetMapping("/api/sentiment")
 public Map<String,String> analyze(@RequestParam String text){
  if(text.isBlank() || text.length()>4000)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"text must contain 1..4000 characters");
  String result=Sentiment.analyze(text);
  registry.counter("sentiment.predictions","sentiment",result).increment();
  return Map.of("sentiment",result,"model","lexicon-v1",
    "pod",System.getenv().getOrDefault("HOSTNAME","local"));
 }
}
