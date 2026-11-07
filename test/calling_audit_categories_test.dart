import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/ride_customer_contact_card.dart';

class AuditSession extends DriverSession {
  AuditSession(http.Client superClient) : super(api: ApiService(client: superClient)) {
    api.accessToken='test-only';api.userId='audit-driver';
  }
  @override bool get authenticated=>api.accessToken!=null;
}
void main(){
  for(final entry in {'rental':'11','service':'22','premium':'33','logistics':'44'}.entries){
    testWidgets('${entry.key}: actual contact widget opens official URI and hides peer phone',(tester)async{
      const id='11111111-1111-4111-8111-111111111111';
      final session=AuditSession(MockClient((_)async=>http.Response(jsonEncode({'success':true,'data':{'rideId':id,'name':'Audit Customer','phone':'+919876543210','callingNumber':'+919153787859'}}),200)));
      session.currentTrip={'id':id,'sector':entry.key,'status':'driver_assigned','bookingId':'${entry.value}00382'};
      addTearDown(session.dispose);await session.refreshCustomerContact();Uri? launched;
      await tester.pumpWidget(ChangeNotifierProvider<DriverSession>.value(value:session,child:MaterialApp(home:Scaffold(body:RideCustomerContactCard(launcher:(uri)async{launched=uri;return true;})))));
      expect(find.text('+919876543210'),findsNothing);expect(session.customerContact?.phone,isNull);
      expect(find.text('Booking ID: ${entry.value}00382'),findsOneWidget);
      await tester.tap(find.text('Call'));await tester.pumpAndSettle();
      expect(launched.toString(),'tel:+919153787859');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
