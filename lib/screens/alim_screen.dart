import 'package:apartment_management_app/screens/permission_screen.dart';
import 'package:apartment_management_app/screens/user_profile_screen.dart';
import 'package:apartment_management_app/screens/welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_supplier.dart';
import '../utils/utils.dart';
import 'multiple_flat_user_profile_screen.dart';

class AlimScreen extends StatefulWidget {
  const AlimScreen({Key? key}) : super(key: key);

  @override
  AlimScreenState createState() => AlimScreenState();

}

class AlimScreenState extends State<AlimScreen> {
  late String _currentDay;
  String? price;
  String? apartmentId;
  List<String> places = [];
  List<String> marketOrders = [];
  List<String> firinOrders = [];
  List<String> manavOrders = [];

  @override
  void initState() {
    super.initState();
    _updateCurrentDay();
    getPlaces();
  }
  // Function to update the current day
  void _updateCurrentDay() async {
    final now = DateTime.now();
    // Convert the current date to a string representation of the day (e.g., Monday, Tuesday, etc.)
    _currentDay = getDayOfWeek(now.weekday);
  }

  void getPlaces() async {
    apartmentId = await getApartmentIdForUser(FirebaseAuth.instance.currentUser!.uid);
    QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('apartmentId', isEqualTo: apartmentId)
        .where('days', arrayContains: _currentDay)
        .get();

    for (var doc in orderSnapshot.docs) {
      String place = doc['place'] ?? '';

      if (place == 'Market') {
        marketOrders.add(place);
      } else if (place == 'Fırın') {
        firinOrders.add(place);
      } else if (place == 'Manav') {
        manavOrders.add(place);
      } else if (!places.contains(place)) {
        places.add(place);
      }
    }
  }

  void showMarketQuantity(String location) {
    Map<String, Map<String, int>> productsDetailsMap = {};
    Map<String, TextEditingController> priceControllersMap = {};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: AlertDialog(
            title: Text('$location Siparişleri'),
            content: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('orders')
                  .where('place', isEqualTo: location)
                  .where('days', arrayContains: _currentDay)
                  .where('apartmentId', isEqualTo: apartmentId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  // Map to hold price controllers for each product

                  snapshot.data?.docs.forEach((doc) {
                    String productName = doc['name'];
                    String details = doc['details'];
                    int productAmount = doc['amount'];

                    // For showing non-detailed orders
                    if (details == "") {
                      details = "Normal";
                    }

                    // If the product already exists in the map, update its details and amount
                    if (productsDetailsMap.containsKey(productName)) {
                      productsDetailsMap[productName]![details] = productAmount;
                    } else {
                      productsDetailsMap[productName] = {details: productAmount};
                    }

                    // Initialize price controllers map
                    priceControllersMap[details] = TextEditingController(text: doc['price'].toString());
                  });

                  List<Widget> productsList = [];

                  productsDetailsMap.forEach((productName, detailsMap) {
                    List<Widget> detailsList = [];

                    detailsMap.forEach((details, amount) {
                      detailsList.add(
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 8.0, right: 16.0, bottom: 8.0),
                              child: Text('$details: $amount', style: const TextStyle(fontSize: 14)),
                            ),
                            SizedBox(
                              width: 40, // Adjust width according to your preference
                              height: 15,
                              child: TextField(
                                controller: priceControllersMap[details],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Text(' TL '),
                          ],
                        ),
                      );
                    });

                    productsList.add(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('> $productName', style: const TextStyle(fontSize: 16)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detailsList,
                          ),
                        ],
                      ),
                    );
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...productsList,
                    ],
                  );
                }
              },
            ),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      // Save the prices to orders
                      productsDetailsMap.forEach((productName, detailsMap) {
                        detailsMap.forEach((details, _) async {
                          String newPrice = priceControllersMap[details]!.text;
                          List<String> orderId = await getOrderIds(productName, details);
                          for (String id in orderId) {
                            await FirebaseFirestore.instance.collection('orders').doc(id).update({
                              'price': double.parse(newPrice),
                            });
                          }
                          updateProductPrice(productName, newPrice);
                        });
                      });
                    },
                    child: const Text('Fiyatları Kaydet', style: TextStyle(color: Colors.teal)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Kapat', style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ],
          ),
        );


      },
    );
  }

  void showOtherQuantity(List<String> places) {
    Map<String, List<Map<String, dynamic>>> ordersByPlace = {};
    Map<String, TextEditingController> priceControllersMap = {};

    // Group orders by place
    for (var place in places) {
      ordersByPlace[place] = [];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: AlertDialog(
            title: const Text('Diğer Yerlerin Siparişleri'),
            content: FutureBuilder(
              future: Future.wait(
                places.map((place) => FirebaseFirestore.instance
                    .collection('orders')
                    .where('place', isEqualTo: place)
                    .where('days', arrayContains: _currentDay)
                    .where('apartmentId', isEqualTo: apartmentId)
                    .get()),
              ),
              builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  for (var querySnapshot in snapshot.data!) {
                    var place = querySnapshot.docs.first['place']; // get place name from the first document
                    for (var doc in querySnapshot.docs) {
                      String productName = doc['name'];
                      String details = doc['details'];
                      int productAmount = doc['amount'];

                      // For showing non-detailed orders
                      if (details == "") {
                        details = "Normal";
                      }

                      ordersByPlace[place]!.add({
                        'productName': productName,
                        'details': details,
                        'amount': productAmount,
                      });

                      // Initialize price controllers map
                      priceControllersMap[productName + details] = TextEditingController(text: doc['price'].toString());
                    }
                  }

                  // Build a list of widgets to display orders by place
                  List<Widget> placeWidgets = [];
                  ordersByPlace.forEach((place, orders) {
                    List<Widget> orderWidgets = [];
                    orders.forEach((order) {
                      orderWidgets.add(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0, top: 8.0, right: 16.0, bottom: 8.0),
                                  child: Text(
                                    '${order['productName']}: ${order['details']} - ${order['amount']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  height: 15,
                                  child: TextField(
                                    controller: priceControllersMap[order['productName'] + order['details']],
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const Text(' TL '),
                              ],
                            ),
                          ],
                        ),
                      );
                    });

                    placeWidgets.add(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('> $place', style: const TextStyle(fontSize: 16)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: orderWidgets,
                          ),
                        ],
                      ),
                    );
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...placeWidgets,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () async {
                              // Save the prices to orders
                              for (var placeOrders in ordersByPlace.entries) {
                                String place = placeOrders.key;
                                List<Map<String, dynamic>> orders = placeOrders.value;

                                for (var order in orders) {
                                  String productName = order['productName'];
                                  String details = order['details'];
                                  int productAmount = order['amount'];
                                  TextEditingController priceController = priceControllersMap[productName + details]!;
                                  String newPrice = priceController.text;

                                  List<String> orderId = await getOrderIds(productName, details);
                                  for (String id in orderId) {
                                    FirebaseFirestore.instance.collection('orders').doc(id).update({
                                      'price': double.parse(newPrice),
                                    });
                                  }
                                }
                              }
                            },
                            child: const Text('Fiyatları Kaydet', style: TextStyle(color: Colors.teal)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Kapat', style: TextStyle(color: Colors.teal)),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    final ap = Provider.of<AuthSupplier>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş Listesi'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [

          FutureBuilder(
              future: getRoleForFlat(ap.userModel.uid), // Assuming 'role' is the field that contains the user's role
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                    color: Colors.teal,
                  ));
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  String userRole = snapshot.data ?? '';
                  return userRole == 'Apartman Yöneticisi' ? IconButton(
                    onPressed: () async {
                      String? apartmentName = await getApartmentIdForUser(ap.userModel.uid);

                      //Checking if the user has more than 1 role
                      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
                          .collection('flats')
                          .where('apartmentId', isEqualTo: apartmentName)
                          .where('isAllowed', isEqualTo: false)
                          .get();

                      if (querySnapshot.docs.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (
                              context) => const PermissionScreen()),
                        );
                      } else {
                        showSnackBar(
                            'Kayıt olmak için izin isteyen kullanıcı bulunmamaktadır.');
                      }
                    },
                    icon: const Icon(Icons.verified_user),
                  ) : const SizedBox(width: 2,height: 2);
                }
              }
          ),
          IconButton(
            onPressed: () async {
              String currentUserUid = ap.userModel.uid;

              //Checking if the user has more than 1 role
              QuerySnapshot querySnapshot = await FirebaseFirestore.instance
                  .collection('flats')
                  .where('uid', isEqualTo: currentUserUid)
                  .get();

              if (querySnapshot.docs.length > 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MultipleFlatUserProfileScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfileScreen()),

                );
              }
            },
            icon: const Icon(Icons.person),
          ),
          IconButton(
            onPressed: () {
              ap.userSignOut().then((value) => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              ));
            },
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLocationButton('Market'),
            const SizedBox(height: 20.0),
            _buildLocationButton('Fırın'),
            const SizedBox(height: 20.0),
            _buildLocationButton('Manav'),
            const SizedBox(height: 20.0),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if(places.isNotEmpty) {
                    showOtherQuantity(places);
                  }
                  else {
                    showSnackBar('Bu yerde sipariş bulunmamaktadır.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
                child: const Text(
                  'Diğer',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton(String location) {
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if(location=='Market' && marketOrders.isNotEmpty) {
            showMarketQuantity(location);
          }
          else if(location=='Fırın' && firinOrders.isNotEmpty) {
            showMarketQuantity(location);
          }
          else if(location=='Manav' && manavOrders.isNotEmpty) {
            showMarketQuantity(location);
          }
          else {
            showSnackBar('Bu yerde sipariş bulunmamaktadır.');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
        ),
        child: Text(
          location,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<List<String>> getOrderIds(String productName, String details) async {
    List<String> orderIds = [];
    if(details == 'Normal') {
      details = '';
    }

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('name', isEqualTo: productName)
        .where('details', isEqualTo: details)
        .get();

    for (var doc in querySnapshot.docs) {
      orderIds.add(doc.id);
    }

    return orderIds;
  }

  Future<void> updateProductPrice(String productName, String price) async {

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('name', isEqualTo: productName)
        .get();

    for (var doc in querySnapshot.docs) {
      FirebaseFirestore.instance.collection('products').doc(doc.id).update({
        'price': double.parse(price),
      });
    }

  }

}