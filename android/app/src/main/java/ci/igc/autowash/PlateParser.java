package ci.igc.autowash;
import java.text.Normalizer;
import java.util.*;
public final class PlateParser {
 public static List<String> candidates(String input){LinkedHashSet<String> result=new LinkedHashSet<>();String text=Normalizer.normalize(input,Normalizer.Form.NFD).replaceAll("\\p{M}","").toUpperCase(Locale.ROOT);for(String line:text.split("[\\r\\n]+")){String plate=line.replaceAll("COTE\\s*D[ '\u2019]*IVOIRE|IMMATRICULATION|REPUBLIQUE","").replaceAll("[^A-Z0-9]","");int digits=plate.replaceAll("[^0-9]","").length(),letters=plate.replaceAll("[^A-Z]","").length();if(plate.length()>=4&&plate.length()<=12&&digits>=2&&digits<=8&&letters>=1&&letters<=6)result.add(plate);}return new ArrayList<>(result);}
}
