package com.infurnus.requests;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import org.json.JSONObject;
import java.util.*;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** Registered in both the UI and Firebase background engines by Flutter's normal registrant. */
public class DriverRequestOverlayPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler,
 ActivityAware, PluginRegistry.NewIntentListener, Application.ActivityLifecycleCallbacks {
 private MethodChannel channel;
 private Activity activity;
 private ActivityPluginBinding binding;
 private static Context context;
 private static MethodChannel uiChannel;
 private static boolean foreground=false, ready=false;
 private static final Handler handler=new Handler(Looper.getMainLooper());
 private static View overlay;
 private static String shownKey;
 private static int shownNotification;
 private static MediaPlayer sound;
 private static Runnable expiryTask;
 private static final String CHANNEL="infurnus_driver_channel_v3";
 private static final String QUIET_CHANNEL="infurnus_driver_overlay_backup";
 private static android.content.SharedPreferences prefs(){return context.getSharedPreferences("ride_request_presentation",Context.MODE_PRIVATE);}
 private static int dp(float v){return Math.round(v*context.getResources().getDisplayMetrics().density);}
 private static boolean overlayAllowed(){return Settings.canDrawOverlays(context);}
 private static NotificationManager notifications(){return (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);}

 @Override public void onAttachedToEngine(FlutterPluginBinding b){
  context=b.getApplicationContext();
  channel=new MethodChannel(b.getBinaryMessenger(),"infurnus/ride_requests");channel.setMethodCallHandler(this);
  channels();
 }
 @Override public void onDetachedFromEngine(FlutterPluginBinding b){channel.setMethodCallHandler(null);if(uiChannel==channel)uiChannel=null;}
 @Override public void onAttachedToActivity(ActivityPluginBinding b){
  binding=b;activity=b.getActivity();uiChannel=channel;b.addOnNewIntentListener(this);
  activity.getApplication().registerActivityLifecycleCallbacks(this);receive(activity.getIntent());
 }
 @Override public void onDetachedFromActivityForConfigChanges(){detach();}
 @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding b){onAttachedToActivity(b);}
 @Override public void onDetachedFromActivity(){detach();}
 private void detach(){
  if(binding!=null)binding.removeOnNewIntentListener(this);
  if(activity!=null)activity.getApplication().unregisterActivityLifecycleCallbacks(this);
  if(uiChannel==channel)uiChannel=null;binding=null;activity=null;
 }
 @Override public boolean onNewIntent(Intent i){return receive(i);}
 private boolean receive(Intent i){
  if(i==null)return false;
  String nonce=i.getStringExtra("infurnus_offer_action_nonce");if(nonce==null)return false;
  String value=prefs().getString("nonce_"+nonce,null);
  prefs().edit().remove("nonce_"+nonce).apply();
  if(value==null)return false; // Never trust an exported activity's arbitrary ride/action extras.
  prefs().edit().putString("pending_action",value).apply();
  if(uiChannel!=null&&ready)uiChannel.invokeMethod("actionAvailable",null);
  return true;
 }
 @Override public void onMethodCall(MethodCall call,MethodChannel.Result result){
  try {
   switch(call.method){
    case "status": result.success(Map.of("overlay",overlayAllowed(),"notifications",Build.VERSION.SDK_INT<24||notifications().areNotificationsEnabled()));break;
    case "permission":
     if(activity==null){result.success(false);break;}
     activity.startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:"+context.getPackageName())));result.success(true);break;
    case "notificationPermission":
     if(activity!=null)requestNotificationAccess();
     result.success(null);break;
    case "ready":ready=true;if(activity!=null)receive(activity.getIntent());result.success(null);break;
    case "takeAction":
     String pending=prefs().getString("pending_action",null);prefs().edit().remove("pending_action").apply();
     result.success(pending);break;
    case "present": result.success(present(new JSONObject((Map<?,?>)call.arguments)));break;
    case "notifyOffer":
     JSONObject offer=new JSONObject((Map<?,?>)call.arguments);
     if(offer.optLong("deadline")>System.currentTimeMillis())fallback(offer,false);
     result.success(true);break;
    case "dismiss": hide();if(shownNotification!=0)notifications().cancel(shownNotification);result.success(null);break;
    case "clear":hide();for(String k:prefs().getAll().keySet())if(k.startsWith("notification_"))try{notifications().cancel(Integer.parseInt(k.substring(13)));}catch(Exception ignored){}prefs().edit().clear().apply();result.success(null);break;
    default:result.notImplemented();
   }
  }catch(Exception e){result.error("REQUEST_PRESENTATION_UNAVAILABLE","Ride request presentation is unavailable",null);}
 }
 private void requestNotificationAccess(){
  if(Build.VERSION.SDK_INT>=33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED
     && (!prefs().getBoolean("notification_permission_requested",false)
         || activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS))){
   prefs().edit().putBoolean("notification_permission_requested",true).apply();
   activity.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},903);
   return;
  }
  Intent settings;
  if(Build.VERSION.SDK_INT>=26){
   channels();
   settings=new Intent(notifications().areNotificationsEnabled()
       ? Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS : Settings.ACTION_APP_NOTIFICATION_SETTINGS)
       .putExtra(Settings.EXTRA_APP_PACKAGE,context.getPackageName())
       .putExtra(Settings.EXTRA_CHANNEL_ID,CHANNEL);
  }else{
   settings=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+context.getPackageName()));
  }
  activity.startActivity(settings);
 }
 private static void channels(){
  if(Build.VERSION.SDK_INT<26)return;
  NotificationChannel channel=new NotificationChannel(CHANNEL,"Infurnus Driver Notifications",NotificationManager.IMPORTANCE_HIGH);
  int raw=context.getResources().getIdentifier("infurnus_alert","raw",context.getPackageName());
  if(raw!=0)channel.setSound(Uri.parse("android.resource://"+context.getPackageName()+"/"+raw),new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build());
  channel.enableVibration(true);notifications().createNotificationChannel(channel);
  NotificationChannel quiet=new NotificationChannel(QUIET_CHANNEL,"Ride request overlay backup",NotificationManager.IMPORTANCE_LOW);
  quiet.setSound(null,null);notifications().createNotificationChannel(quiet);
 }
 private static String text(JSONObject d,String key,String fallback){String value=d.optString(key,fallback);return value.length()>500?value.substring(0,500):value;}
 private static Intent action(JSONObject d,String action){
  String nonce=UUID.randomUUID().toString();
  JSONObject pending=new JSONObject();
  try{pending.put("rideId",d.getString("rideId"));pending.put("action",action);pending.put("deadline",d.getLong("deadline"));}catch(Exception ignored){}
  prefs().edit().putString("nonce_"+nonce,pending.toString()).apply();
  Intent intent=context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
  if(intent==null)return null;
  intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TOP|Intent.FLAG_ACTIVITY_SINGLE_TOP);
  if(Build.VERSION.SDK_INT>=29)intent.setIdentifier(nonce);intent.putExtra("infurnus_offer_action_nonce",nonce);return intent;
 }
 private static void choose(JSONObject d,String action){
  Intent intent=action(d,action);hide();
  if(intent!=null){try{context.startActivity(intent);}catch(Exception ignored){fallback(d,false);}}
 }
 private static void fallback(JSONObject d,boolean quiet){
  Intent intent=action(d,"review");if(intent==null)return;
  int id=text(d,"key", "").hashCode()&0x7fffffff;
  if(shownNotification!=0 && shownNotification!=id)notifications().cancel(shownNotification);
  shownNotification=id;
  prefs().edit().putBoolean("notification_"+id,true).apply();
  PendingIntent open=PendingIntent.getActivity(context,id,intent,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
  Notification.Builder builder=Build.VERSION.SDK_INT>=26?new Notification.Builder(context,quiet?QUIET_CHANNEL:CHANNEL):new Notification.Builder(context);
  long remaining=d.optLong("deadline")-System.currentTimeMillis();
  builder.setSmallIcon(context.getApplicationInfo().icon).setContentTitle("New Ride Request")
   .setContentText(text(d,"pickup","Open INFURNUS to review this request"))
   .setStyle(new Notification.BigTextStyle().bigText("Pickup: "+text(d,"pickup","Available in app")+"\nDrop: "+text(d,"drop","Available after PIN verification")))
   .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true).setCategory(Notification.CATEGORY_EVENT)
   .setPriority(quiet?Notification.PRIORITY_LOW:Notification.PRIORITY_MAX);
  if(Build.VERSION.SDK_INT>=26)builder.setTimeoutAfter(Math.max(1,remaining));
  try{notifications().notify(id,builder.build());}catch(SecurityException ignored){}
 }
 private static boolean present(JSONObject d){
  String key=d.optString("key");long deadline=d.optLong("deadline");
  if(key.isEmpty()||d.optString("rideId").isEmpty()||deadline<=System.currentTimeMillis())return false;
  long previous=prefs().getLong("seen_"+key,0);
  boolean fresh=previous==0;
  if(fresh){
   android.content.SharedPreferences.Editor edit=prefs().edit();
   for(Map.Entry<String,?> e:prefs().getAll().entrySet())if(e.getKey().startsWith("seen_")&&e.getValue() instanceof Long&&(Long)e.getValue()<System.currentTimeMillis())edit.remove(e.getKey());
   edit.putLong("seen_"+key,deadline).apply();
  }
  if(foreground){hide();if(shownNotification!=0)notifications().cancel(shownNotification);if(fresh)playAlert();return true;}
  if(key.equals(shownKey)&&overlay!=null)return true;
  if(prefs().getBoolean("dismissed_"+key,false))return true;
  if(!overlayAllowed()){fallback(d,false);return true;}
  try{
   hide();shownKey=key;
   LinearLayout card=card(d);
   WindowManager.LayoutParams params=new WindowManager.LayoutParams(Math.min(dp(430),context.getResources().getDisplayMetrics().widthPixels-dp(24)),WindowManager.LayoutParams.WRAP_CONTENT,Build.VERSION.SDK_INT>=26?WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY:WindowManager.LayoutParams.TYPE_PHONE,WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL|WindowManager.LayoutParams.FLAG_DIM_BEHIND,PixelFormat.TRANSLUCENT);
   params.gravity=Gravity.CENTER;params.dimAmount=.18f;
   ((WindowManager)context.getSystemService(Context.WINDOW_SERVICE)).addView(card,params);overlay=card;
   fallback(d,true);if(fresh)playAlert();
   expiryTask=()->{hide();notifications().cancel(shownNotification);};handler.postDelayed(expiryTask,deadline-System.currentTimeMillis());
   return true;
  }catch(Exception ignored){hide();fallback(d,false);return true;}
 }
 private static void playAlert(){
  if(Build.VERSION.SDK_INT>=24 && !notifications().areNotificationsEnabled())return;
  NotificationChannel alertChannel=Build.VERSION.SDK_INT>=26?notifications().getNotificationChannel(CHANNEL):null;
  if(alertChannel!=null && alertChannel.getImportance()==NotificationManager.IMPORTANCE_NONE)return;
  if(alertChannel==null || alertChannel.shouldVibrate()){
   Vibrator vibrator=(Vibrator)context.getSystemService(Context.VIBRATOR_SERVICE);
   if(vibrator!=null && vibrator.hasVibrator()){
    if(Build.VERSION.SDK_INT>=26)vibrator.vibrate(VibrationEffect.createOneShot(250,VibrationEffect.DEFAULT_AMPLITUDE));
    else vibrator.vibrate(250);
   }
  }
  if(alertChannel!=null && alertChannel.getSound()==null)return;
  int raw=context.getResources().getIdentifier("infurnus_alert","raw",context.getPackageName());
  if(raw==0)return;
  try{if(sound!=null){sound.release();sound=null;}sound=MediaPlayer.create(context,raw);if(sound!=null){sound.setOnCompletionListener(p->{p.release();if(sound==p)sound=null;});sound.start();}}catch(Exception ignored){}
 }
 private static void hide(){
  if(expiryTask!=null){handler.removeCallbacks(expiryTask);expiryTask=null;}
  if(overlay!=null){try{((WindowManager)context.getSystemService(Context.WINDOW_SERVICE)).removeView(overlay);}catch(Exception ignored){}overlay=null;}
  shownKey=null;
  if(sound!=null){try{sound.release();}catch(Exception ignored){}sound=null;}
 }
 private static GradientDrawable background(int color,int stroke,float radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));if(stroke!=0)d.setStroke(dp(1),stroke);return d;}
 private static TextView label(String value,int size,int color,boolean bold){TextView v=new TextView(context);v.setText(value);v.setTextSize(size);v.setTextColor(color);if(bold)v.setTypeface(Typeface.DEFAULT,Typeface.BOLD);return v;}
 private static void padding(View v,int x,int y){v.setPadding(dp(x),dp(y),dp(x),dp(y));}
 private static LinearLayout card(JSONObject d){
  final int navy=Color.rgb(21,32,57),green=Color.rgb(0,177,19),red=Color.rgb(226,52,58),ink=Color.rgb(19,24,34);
  LinearLayout root=new LinearLayout(context);root.setOrientation(LinearLayout.VERTICAL);root.setBackground(background(Color.WHITE,Color.rgb(225,228,235),22));root.setElevation(dp(16));root.setClipToOutline(true);
  LinearLayout header=new LinearLayout(context);header.setGravity(Gravity.CENTER_VERTICAL);padding(header,18,16);
  GradientDrawable gradient=new GradientDrawable(GradientDrawable.Orientation.TL_BR,new int[]{navy,Color.rgb(39,55,87)});header.setBackground(gradient);
  TextView title=label("◉  New Ride Request",22,Color.WHITE,true);header.addView(title,new LinearLayout.LayoutParams(0,-2,1));
  TextView close=label("×",30,Color.WHITE,false);close.setContentDescription("Close ride request");close.setOnClickListener(v->{prefs().edit().putBoolean("dismissed_"+d.optString("key"),true).apply();hide();});padding(close,8,0);header.addView(close);root.addView(header);
  LinearLayout body=new LinearLayout(context);body.setOrientation(LinearLayout.VERTICAL);padding(body,18,16);root.addView(body);
  String sector=text(d,"sectorLabel","");if(!sector.isEmpty()){TextView category=label(sector,14,Color.rgb(38,105,43),true);category.setGravity(Gravity.CENTER);padding(category,8,6);category.setBackground(background(Color.rgb(235,249,237),0,10));body.addView(category);}
  location(body,"Pickup",text(d,"pickup","Pickup details available in app"),green);
  View line=new View(context);line.setBackgroundColor(Color.rgb(232,234,240));LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(1));lp.setMargins(dp(38),dp(3),0,dp(3));body.addView(line,lp);
  location(body,"Drop",text(d,"drop","Available after PIN verification"),red);
  TextView metrics=label(text(d,"vehicle","")+"   ·   "+text(d,"distance","Distance unavailable")+"   ·   "+text(d,"duration","ETA unavailable"),15,ink,true);padding(metrics,12,14);metrics.setBackground(background(Color.rgb(247,248,251),Color.rgb(232,234,240),12));body.addView(metrics);
  String fare=text(d,"fare","");if(!fare.isEmpty()){TextView price=label("Ride Price                         "+fare,19,Color.rgb(0,127,22),true);padding(price,12,10);price.setBackground(background(Color.rgb(232,248,234),0,12));LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,-2);p.topMargin=dp(10);body.addView(price,p);}
  LinearLayout buttons=new LinearLayout(context);LinearLayout.LayoutParams bp=new LinearLayout.LayoutParams(-1,dp(54));bp.topMargin=dp(16);body.addView(buttons,bp);
  TextView reject=label("×  Reject",18,red,true);reject.setGravity(Gravity.CENTER);reject.setBackground(background(Color.WHITE,red,14));reject.setOnClickListener(v->choose(d,"reject"));buttons.addView(reject,new LinearLayout.LayoutParams(0,-1,1));
  Space gap=new Space(context);buttons.addView(gap,new LinearLayout.LayoutParams(dp(12),1));
  TextView accept=label("✓  Accept",18,Color.WHITE,true);accept.setGravity(Gravity.CENTER);GradientDrawable bg=new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,new int[]{green,Color.rgb(0,153,7)});bg.setCornerRadius(dp(14));accept.setBackground(bg);accept.setOnClickListener(v->choose(d,"accept"));buttons.addView(accept,new LinearLayout.LayoutParams(0,-1,1));
  return root;
 }
 private static void location(LinearLayout body,String title,String address,int color){
  LinearLayout row=new LinearLayout(context);row.setGravity(Gravity.CENTER_VERTICAL);padding(row,0,13);
  TextView marker=label("●",27,color,true);row.addView(marker,new LinearLayout.LayoutParams(dp(38),-2));
  LinearLayout lines=new LinearLayout(context);lines.setOrientation(LinearLayout.VERTICAL);lines.addView(label(title,14,Color.rgb(88,94,107),false));lines.addView(label(address,17,Color.rgb(19,24,34),true));row.addView(lines,new LinearLayout.LayoutParams(0,-2,1));body.addView(row);
 }
 @Override public void onActivityResumed(Activity a){if(a==activity){foreground=true;hide();if(uiChannel!=null&&ready)uiChannel.invokeMethod("actionAvailable",null);}}
 @Override public void onActivityPaused(Activity a){if(a==activity)foreground=false;}
 @Override public void onActivityCreated(Activity a,Bundle b){} @Override public void onActivityStarted(Activity a){} @Override public void onActivityStopped(Activity a){} @Override public void onActivitySaveInstanceState(Activity a,Bundle b){} @Override public void onActivityDestroyed(Activity a){}
}
