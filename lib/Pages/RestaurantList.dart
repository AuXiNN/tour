import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tour/AppColors/colors.dart';
import 'package:tour/Pages/RestaurantDetails.dart';
import 'package:tour/Widgets/BottomNavigationBar.dart';

enum SortOption { alphabetically, rating }

class RestaurantList extends StatefulWidget {
  final String city;

  RestaurantList({required this.city});

  @override
  _RestaurantListState createState() => _RestaurantListState();
}

class _RestaurantListState extends State<RestaurantList> {
  Set<String> userFavorites = {};
  SortOption _sortOption = SortOption.alphabetically;

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userEmail = user.email; // Get the user's email
      var favsSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userEmail) // Use email to reference the document
          .collection('favorites_restaurants')
          .get();

      setState(() {
        userFavorites = Set.from(favsSnapshot.docs.map((doc) => doc.id));
      });
    }
  }

  void _toggleFavoriteRestaurant(String restaurantId, String restaurantName) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Fluttertoast.showToast(
        msg: "You must be logged in to add to favorites",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }
    var userEmail = currentUser.email; // Get the user's email

    var favoritesRef = FirebaseFirestore.instance
        .collection('Users')
        .doc(userEmail) // Use email to reference the document
        .collection('favorites_restaurants');
    bool isCurrentlyFavorite = userFavorites.contains(restaurantId);

    if (isCurrentlyFavorite) {
      await favoritesRef.doc(restaurantId).delete();
      setState(() {
        userFavorites.remove(restaurantId);
      });
      Fluttertoast.showToast(
        msg: "$restaurantName has been removed from Favorites",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      await favoritesRef.doc(restaurantId).set({
        'name': restaurantName,
        'timestamp': Timestamp.now(),
      });
      setState(() {
        userFavorites.add(restaurantId);
      });
      Fluttertoast.showToast(
        msg: "$restaurantName has been added to Favorites",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Stream<QuerySnapshot> _restaurantStream() {
    Query query = FirebaseFirestore.instance.collection(_getCollectionName());
    switch (_sortOption) {
      case SortOption.alphabetically:
        query = query.orderBy('name');
        break;
      case SortOption.rating:
        query = query.orderBy('rating', descending: true);
        break;
    }
    return query.snapshots();
  }

  String _getCollectionName() {
    switch (widget.city.toLowerCase()) {
      case 'amman':
        return 'amman_restaurants';
      case 'aqaba':
        return 'aqaba_restaurants';
      case 'jerash':
        return 'jerash_restaurants';
      case 'ajloun':
        return 'ajloun_restaurants';
      case 'petra':
        return 'petra_restaurants';
      case 'dead sea':
        return 'deadsea_restaurants';
      case 'wadi rum':
        return 'wadirum_restaurants';
      default:
        return 'restaurants';
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseStorage _storage = FirebaseStorage.instance;

    return Scaffold(
      backgroundColor: AppColors.backgroundcolor,
      appBar: AppBar(
        backgroundColor: AppColors.buttomcolor,
        centerTitle: true,
        title: Text(
          'Restaurants & Cafes',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          DropdownButton<SortOption>(
            value: _sortOption,
            onChanged: (SortOption? newValue) {
              if (newValue != null) {
                setState(() {
                  _sortOption = newValue;
                });
              }
            },
            items: SortOption.values.map((SortOption option) {
              return DropdownMenuItem<SortOption>(
                value: option,
                child: Text(option == SortOption.alphabetically
                    ? 'Alphabetically'
                    : 'By Rating'),
              );
            }).toList(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _restaurantStream(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }

          var restaurantList = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurantList.length,
            itemBuilder: (context, index) {
              var restaurant = restaurantList[index].data() as Map<String, dynamic>;
              String restaurantId = restaurantList[index].id; // Correctly defined restaurantId

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      FutureBuilder<String>(
                        future: _storage.ref('${_getCollectionName()}/${restaurant['image']}').getDownloadURL(),
                        builder: (BuildContext context, AsyncSnapshot<String> imageSnapshot) {
                          if (imageSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (imageSnapshot.hasError) {
                            return const Text('Error loading image');
                          } else {
                            return Image.network(
                              imageSnapshot.data!,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          userFavorites.contains(restaurantId) ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        onPressed: () => _toggleFavoriteRestaurant(restaurantId, restaurant['name']),
                      ),
                    ],
                  ),
                                              ListTile(
                              title: Text(restaurant['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 20)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Classification: ${restaurant['classification']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        const TextSpan(
                                            text: 'Location: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text: restaurant[
                                                'location']), // Normal weight for the actual location
                                      ],
                                    ),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        const TextSpan(
                                            text: 'Working Hours: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text: restaurant[
                                                'workingHours']), // Normal weight for the actual location
                                      ],
                                    ),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        const TextSpan(
                                            text: 'Phone Number: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text: restaurant[
                                                'phoneNumber']), // Normal weight for the actual location
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      RatingBar.builder(
                                        initialRating: double.parse(
                                            restaurant['rating'].toString()),
                                        minRating: 1,
                                        direction: Axis.horizontal,
                                        allowHalfRating: true,
                                        itemCount: 5,
                                        itemSize: 20.0,
                                        itemPadding: const EdgeInsets.symmetric(
                                            horizontal: 2.0),
                                        itemBuilder: (context, _) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        onRatingUpdate: (rating) {},
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RestaurantDetails(
                                      restaurantId: restaurantList[index].id,
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: const BottomNav(isHomeEnabled: true),
    );
  }
}
