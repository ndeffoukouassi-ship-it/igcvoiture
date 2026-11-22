package ci.igc.autowash;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.webkit.*;
import android.widget.*;
import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.json.JSONObject;
import java.io.File;
import java.io.OutputStream;
import java.util.Collections;

public class MainActivity extends ComponentActivity {
 static final String ORIGIN="https://igc-autowash.onrender.com";
 WebView web; ValueCallback<Uri[]> chooser; Uri cameraUri; byte[] pendingDownload; String downloadName="export-autowash.txt";
 ActivityResultLauncher<Intent> scan=registerForActivityResult(new ActivityResultContracts.StartActivityForResult(),result->{
  if(result.getResultCode()==Activity.RESULT_OK&&result.getData()!=null){String plate=result.getData().getStringExtra("plate");if(plate!=null&&plate.matches("[A-Z0-9]{4,15}")&&trusted())web.evaluateJavascript("(()=>{const p=document.getElementById('plate');if(p){p.value="+JSONObject.quote(plate)+";p.dispatchEvent(new Event('input',{bubbles:true}));document.getElementById('ocr').textContent='Plaque reconnue par la caméra Android. Vérifiez le numéro avant validation.'}})()",null);}
 });
 ActivityResultLauncher<Intent> picker=registerForActivityResult(new ActivityResultContracts.StartActivityForResult(),result->{if(chooser==null)return;Uri[] uris=null;if(result.getResultCode()==Activity.RESULT_OK){if(result.getData()!=null&&result.getData().getData()!=null)uris=new Uri[]{result.getData().getData()};else if(cameraUri!=null)uris=new Uri[]{cameraUri};}chooser.onReceiveValue(uris);chooser=null;cameraUri=null;});
 ActivityResultLauncher<String> cameraPermission=registerForActivityResult(new ActivityResultContracts.RequestPermission(),ok->openPicker(ok));
 ActivityResultLauncher<String> saveDocument=registerForActivityResult(new ActivityResultContracts.CreateDocument("application/octet-stream"),uri->{if(uri!=null&&pendingDownload!=null)try(OutputStream out=getContentResolver().openOutputStream(uri)){out.write(pendingDownload);toast("Fichier enregistré");}catch(Exception e){toast("Enregistrement impossible");}pendingDownload=null;});
 boolean trusted(){return web!=null&&web.getUrl()!=null&&ORIGIN.equals(origin(web.getUrl()));}
 static String origin(String value){try{Uri u=Uri.parse(value);return u.getScheme()+"://"+u.getHost()+(u.getPort()!=-1?":"+u.getPort():"");}catch(Exception e){return "";}}
 void toast(String message){Toast.makeText(this,message,Toast.LENGTH_LONG).show();}
 @Override public void onCreate(Bundle state){super.onCreate(state);
  LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(Color.parseColor("#073C2E"));
  LinearLayout bar=new LinearLayout(this);bar.setPadding(12,8,12,8);TextView title=new TextView(this);title.setText("IGC AutoWash");title.setTextColor(Color.parseColor("#E8CC7A"));title.setTextSize(20);bar.addView(title,new LinearLayout.LayoutParams(0,-2,1));Button refresh=new Button(this);refresh.setText("Actualiser");bar.addView(refresh);root.addView(bar);
  LinearLayout navigation=new LinearLayout(this);android.widget.HorizontalScrollView navigationScroll=new android.widget.HorizontalScrollView(this);navigationScroll.addView(navigation);root.addView(navigationScroll);Button home=new Button(this);home.setText("Accueil");navigation.addView(home);Button back=new Button(this);back.setText("Retour");navigation.addView(back);Button browser=new Button(this);browser.setText("Navigateur");navigation.addView(browser);
  web=new WebView(this);root.addView(web,new LinearLayout.LayoutParams(-1,0,1));setContentView(root);
  // Respect system insets on Android 15's edge-to-edge default.
  androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(root,(view,insets)->{androidx.core.graphics.Insets s=insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars());view.setPadding(s.left,s.top,s.right,s.bottom);return insets;});
  WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(true);settings.setAllowFileAccess(false);settings.setAllowContentAccess(true);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);settings.setSafeBrowsingEnabled(true);settings.setMediaPlaybackRequiresUserGesture(true);CookieManager.getInstance().setAcceptThirdPartyCookies(web,false);
  web.setWebViewClient(new WebViewClient(){
   @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest request){Uri uri=request.getUrl();if(ORIGIN.equals(origin(uri.toString())))return false;if(request.isForMainFrame()&&(uri.getScheme().equals("https")||uri.getScheme().equals("mailto")||uri.getScheme().equals("tel"))){try{startActivity(new Intent(Intent.ACTION_VIEW,uri));}catch(Exception e){toast("Lien indisponible");}}return true;}
   @Override public void onPageFinished(WebView v,String url){if(trusted())injectBridge();}
   @Override public void onReceivedError(WebView v,WebResourceRequest r,WebResourceError e){if(r.isForMainFrame())toast("Connexion indisponible. Vérifiez Internet puis appuyez sur Actualiser.");}
  });
  if(WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){
   WebViewCompat.addWebMessageListener(web,"AutoWashNative",Collections.singleton(ORIGIN),(view,message,source,isMainFrame,reply)->{if(!isMainFrame||!ORIGIN.equals(origin(source.toString()))||!trusted())return;runOnUiThread(()->handleMessage(message.getData()));});
  }
  web.setWebChromeClient(new WebChromeClient(){@Override public boolean onShowFileChooser(WebView v,ValueCallback<Uri[]> callback,FileChooserParams params){if(!trusted())return false;if(chooser!=null)chooser.onReceiveValue(null);chooser=callback;if(ContextCompat.checkSelfPermission(MainActivity.this,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)openPicker(true);else cameraPermission.launch(Manifest.permission.CAMERA);return true;}});
  web.setDownloadListener((url,agent,disposition,mime,length)->{if(!trusted())return;if(url.startsWith("blob:"+ORIGIN)){web.evaluateJavascript("fetch("+JSONObject.quote(url)+").then(r=>r.blob()).then(b=>{if(b.size>15000000)throw Error();const r=new FileReader();r.onload=()=>AutoWashNative.postMessage(JSON.stringify({action:'download',data:r.result,mime:b.type}));r.readAsDataURL(b)})",null);}else toast("Utilisez le partage du reçu ou ouvrez le site dans Chrome pour ce fichier.");});
  home.setOnClickListener(v->{if(trusted())web.evaluateJavascript("(()=>{document.querySelectorAll('dialog[open]').forEach(d=>d.close());document.querySelector('nav button[data-view=dashboard]')?.click()})()",null);else web.loadUrl(ORIGIN+"/?android=1");});
  back.setOnClickListener(v->getOnBackPressedDispatcher().onBackPressed());
  browser.setOnClickListener(v->{try{startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(ORIGIN)));}catch(Exception e){toast("Navigateur indisponible");}});
  refresh.setOnClickListener(v->web.loadUrl(ORIGIN+"/?android=1"));
  getOnBackPressedDispatcher().addCallback(this,new OnBackPressedCallback(true){@Override public void handleOnBackPressed(){
   if(!trusted()){if(web.canGoBack())web.goBack();else finish();return;}
   // Les onglets web ne créent pas d'entrée dans l'historique WebView : retour au tableau de bord d'abord.
   String navigate="(()=>{const dialogs=document.querySelectorAll('dialog[open]');if(dialogs.length){const d=dialogs[dialogs.length-1];d.dispatchEvent(new Event('cancel'));d.close();return true;}const current=document.querySelector('nav button.active');const home=document.querySelector('nav button[data-view=dashboard]');if(current&&current.dataset.view!=='dashboard'&&home){home.click();return true;}return false;})()";
   web.evaluateJavascript(navigate,handled->{if("true".equals(handled))return;if(web.canGoBack())web.goBack();else finish();});
  }});
  if(state!=null)web.restoreState(state);else web.loadUrl(ORIGIN+"/?android=1");
 }
 void handleMessage(String raw){try{if(raw==null||raw.length()>21000000)return;JSONObject message=new JSONObject(raw);String action=message.optString("action");
  if(action.equals("scan")){scan.launch(new Intent(this,ScanActivity.class));}
  else if(action.equals("share")){Intent i=new Intent(Intent.ACTION_SEND);i.setType("text/plain");i.putExtra(Intent.EXTRA_TEXT,message.optString("text")+"\n"+message.optString("url"));startActivity(Intent.createChooser(i,"Partager avec le client"));}
  else if(action.equals("download")){String data=message.optString("data");int comma=data.indexOf(',');if(comma<0||!data.substring(0,comma).endsWith(";base64"))return;pendingDownload=android.util.Base64.decode(data.substring(comma+1),android.util.Base64.DEFAULT);String mime=message.optString("mime");downloadName="autowash-export"+(mime.contains("json")?".json":mime.contains("csv")?".csv":".txt");saveDocument.launch(downloadName);}
 }catch(Exception e){toast("Action indisponible. Réessayez.");}}
 void injectBridge(){if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))return;
  web.evaluateJavascript("(()=>{if(window.__autowashNativeBound)return;window.__autowashNativeBound=true;document.addEventListener('click',e=>{const label=e.target.closest('label.camera');const form=document.getElementById('new');if(label&&form&&form.open){e.preventDefault();e.stopImmediatePropagation();AutoWashNative.postMessage(JSON.stringify({action:'scan'}))}},true);if(!navigator.share)navigator.share=d=>{AutoWashNative.postMessage(JSON.stringify({action:'share',text:d.text||'',url:d.url||''}));return Promise.resolve()};})()",null);
 }
 void openPicker(boolean camera){try{Intent files=new Intent(Intent.ACTION_GET_CONTENT);files.setType("image/*");files.addCategory(Intent.CATEGORY_OPENABLE);Intent choose=Intent.createChooser(files,"Photo ou galerie");if(camera){File folder=new File(getCacheDir(),"photos");folder.mkdirs();File photo=File.createTempFile("receipt-",".jpg",folder);cameraUri=FileProvider.getUriForFile(this,getPackageName()+".files",photo);Intent capture=new Intent(MediaStore.ACTION_IMAGE_CAPTURE);capture.putExtra(MediaStore.EXTRA_OUTPUT,cameraUri);capture.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);choose.putExtra(Intent.EXTRA_INITIAL_INTENTS,new Intent[]{capture});}picker.launch(choose);}catch(Exception e){if(chooser!=null)chooser.onReceiveValue(null);chooser=null;toast("Sélection de photo impossible");}}
 @Override public void onSaveInstanceState(Bundle state){super.onSaveInstanceState(state);web.saveState(state);}
 @Override public void onDestroy(){if(chooser!=null)chooser.onReceiveValue(null);web.destroy();super.onDestroy();}
}
