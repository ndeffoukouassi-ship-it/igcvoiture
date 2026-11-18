package ci.igc.autowash;
import org.junit.Test;
import static org.junit.Assert.*;
public class PlateParserTest {
 @Test public void keepsPlateLettersAndDigits(){assertEquals("D179535",PlateParser.candidates("D17 9535").get(0));assertEquals("AB123CD",PlateParser.candidates("AB-123-CD").get(0));}
 @Test public void rejectsCountryAndNumbersAlone(){assertTrue(PlateParser.candidates("COTE D’IVOIRE\n2026").isEmpty());}
}
