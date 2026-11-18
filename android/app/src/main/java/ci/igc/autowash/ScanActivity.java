package ci.igc.autowash;
import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import androidx.activity.ComponentActivity;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.camera.core.*;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import java.util.*;
import java.util.concurrent.*;

public class ScanActivity extends ComponentActivity {
 PreviewView preview;ImageCapture capture;EditText plate;TextView status;Button take,accept;TextRecognizer recognizer;ExecutorService worker=Executors.newSingleThreadExecutor();
 final ActivityResultLauncher<String> permission=registerForActivityResult(new ActivityResultContracts.RequestPermission(),ok->{if(ok)startCamera();else{status.setText("Caméra refusée. Vous pouvez saisir la plaque manuellement.");take.setEnabled(false);}});
 @Override public void onCreate(Bundle state){super.onCreate(state);recognizer=TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
 LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(20,20,20,20);root.setBackgroundColor(Color.parseColor("#073C2E"));TextView title=new TextView(this);title.setText("Scanner une plaque");title.setTextColor(Color.parseColor("#E5C76C"));title.setTextSize(24);root.addView(title);
 status=new TextView(this);status.setText("Placez la plaque entière dans le cadre, de face et sans reflet.");status.setTextColor(Color.WHITE);status.setPadding(0,12,0,12);root.addView(status);
 FrameLayout frame=new FrameLayout(this);preview=new PreviewView(this);preview.setScaleType(PreviewView.ScaleType.FIT_CENTER);frame.addView(preview,new FrameLayout.LayoutParams(-1,-1));frame.addView(new FrameGuide(this),new FrameLayout.LayoutParams(-1,-1));root.addView(frame,new LinearLayout.LayoutParams(-1,0,1));
 plate=new EditText(this);plate.setSingleLine(true);plate.setHint("Numéro de plaque");plate.setTextColor(Color.BLACK);plate.setBackgroundColor(Color.WHITE);plate.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS);root.addView(plate,new LinearLayout.LayoutParams(-1,-2));
 take=new Button(this);take.setText("Photographier et lire");root.addView(take);accept=new Button(this);accept.setText("Confirmer ce numéro");root.addView(accept);Button cancel=new Button(this);cancel.setText("Annuler");root.addView(cancel);setContentView(root);
 androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(root,(v,insets)->{androidx.core.graphics.Insets i=insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars());v.setPadding(i.left+20,i.top+20,i.right+20,i.bottom+20);return insets;});
 take.setOnClickListener(v->readPhoto());accept.setOnClickListener(v->{String value=plate.getText().toString().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]","");if(!value.matches("(?=.*[A-Z])(?=.*[0-9])[A-Z0-9]{4,15}")){plate.setError("Vérifiez les lettres et les chiffres");return;}setResult(RESULT_OK,new Intent().putExtra("plate",value));finish();});cancel.setOnClickListener(v->finish());
 if(ContextCompat.checkSelfPermission(this,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)startCamera();else permission.launch(Manifest.permission.CAMERA);
 }
 void startCamera(){ListenableFuture<ProcessCameraProvider> future=ProcessCameraProvider.getInstance(this);future.addListener(()->{try{ProcessCameraProvider provider=future.get();Preview usePreview=new Preview.Builder().build();usePreview.setSurfaceProvider(preview.getSurfaceProvider());capture=new ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).setTargetResolution(new android.util.Size(1280,960)).build();provider.unbindAll();provider.bindToLifecycle(this,CameraSelector.DEFAULT_BACK_CAMERA,usePreview,capture);}catch(Exception e){status.setText("Caméra indisponible. Saisissez le numéro manuellement.");take.setEnabled(false);}},ContextCompat.getMainExecutor(this));}
 void readPhoto(){if(capture==null)return;take.setEnabled(false);accept.setEnabled(false);status.setText("Lecture en cours…");capture.takePicture(worker,new ImageCapture.OnImageCapturedCallback(){@Override public void onCaptureSuccess(ImageProxy image){try{Bitmap bitmap=image.toBitmap();int rotation=image.getImageInfo().getRotationDegrees();if(rotation!=0){Matrix matrix=new Matrix();matrix.postRotate(rotation);bitmap=Bitmap.createBitmap(bitmap,0,0,bitmap.getWidth(),bitmap.getHeight(),matrix,true);}int x=(int)(bitmap.getWidth()*.04f),y=(int)(bitmap.getHeight()*.30f),width=(int)(bitmap.getWidth()*.92f),height=(int)(bitmap.getHeight()*.40f);Bitmap region=Bitmap.createBitmap(bitmap,x,y,Math.min(width,bitmap.getWidth()-x),Math.min(height,bitmap.getHeight()-y));InputImage input=InputImage.fromBitmap(region,0);recognizer.process(input).addOnSuccessListener(text->{Map<String,Integer> votes=new LinkedHashMap<>();for(com.google.mlkit.vision.text.Text.TextBlock block:text.getTextBlocks())for(com.google.mlkit.vision.text.Text.Line line:block.getLines())for(String candidate:PlateParser.candidates(line.getText()))votes.put(candidate,votes.getOrDefault(candidate,0)+1);String best=null;int score=-1;for(String candidate:votes.keySet()){int s=votes.get(candidate)*10+candidate.replaceAll("[^0-9]","").length();if(s>score){best=candidate;score=s;}}if(best!=null){plate.setText(best);status.setText("Vérifiez le numéro reconnu avant de confirmer.");}else status.setText("Lecture incertaine. Reprenez la photo de plus près ou saisissez la plaque.");}).addOnFailureListener(e->status.setText("Lecture impossible. Reprenez la photo ou saisissez la plaque.")).addOnCompleteListener(task->{image.close();take.setEnabled(true);accept.setEnabled(true);});}catch(Exception e){image.close();runOnUiThread(()->{status.setText("Image illisible. Réessayez.");take.setEnabled(true);accept.setEnabled(true);});}}@Override public void onError(ImageCaptureException e){runOnUiThread(()->{status.setText("Photo impossible. Réessayez.");take.setEnabled(true);accept.setEnabled(true);});}});}
 @Override public void onDestroy(){recognizer.close();worker.shutdown();super.onDestroy();}
 static class FrameGuide extends View {Paint paint=new Paint(3);FrameGuide(android.content.Context c){super(c);}protected void onDraw(Canvas canvas){super.onDraw(canvas);float left=getWidth()*.08f,right=getWidth()*.92f,top=getHeight()*.39f,bottom=getHeight()*.61f;paint.setColor(0x66000000);paint.setStyle(Paint.Style.FILL);canvas.drawRect(0,0,getWidth(),top,paint);canvas.drawRect(0,bottom,getWidth(),getHeight(),paint);paint.setColor(Color.rgb(225,192,92));paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(5);canvas.drawRoundRect(left,top,right,bottom,16,16,paint);}}
}
