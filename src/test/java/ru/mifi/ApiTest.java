package ru.mifi;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest @AutoConfigureMockMvc
class ApiTest {
 @Autowired MockMvc mvc;
 @ParameterizedTest @CsvSource({"hello,positive","BAD!,negative","unknown,neutral","good bad,neutral","отлично,positive","плохо,negative","goodbye,neutral","GREAT,positive"})
 void lexicalCases(String text,String expected){assertEquals(expected,Sentiment.analyze(text));}
 @Test void response() throws Exception {mvc.perform(get("/api/sentiment").param("text","hello")).andExpect(status().isOk()).andExpect(jsonPath("$.sentiment").value("positive")).andExpect(jsonPath("$.model").value("lexicon-v1"));}
 @Test void missing() throws Exception {mvc.perform(get("/api/sentiment")).andExpect(status().isBadRequest());}
 @Test void blank() throws Exception {mvc.perform(get("/api/sentiment").param("text"," ")).andExpect(status().isBadRequest());}
 @Test void longInput() throws Exception {mvc.perform(get("/api/sentiment").param("text","a".repeat(4001))).andExpect(status().isBadRequest());}
}
