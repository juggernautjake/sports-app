import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'event_form_screen.dart';
import 'package:geolocator/geolocator.dart';

class EventDetailsScreen extends StatelessWidget {
  final String eventId;

  EventDetailsScreen({required this.eventId});

  Future<void> _toggleRSVP(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentReference eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot eventSnapshot = await transaction.get(eventRef);

        if (!eventSnapshot.exists) {
          throw Exception("Event does not exist!");
        }

        List<String> rsvps = List<String>.from(eventSnapshot['rsvps'] ?? []);
        if (rsvps.contains(user.email)) {
          rsvps.remove(user.email);
        } else {
          rsvps.add(user.email!);
        }

        transaction.update(eventRef, {
          'rsvps': rsvps,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RSVP Updated')));
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentReference eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot eventSnapshot = await transaction.get(eventRef);

        if (!eventSnapshot.exists) {
          throw Exception("Event does not exist!");
        }

        List<String> favorites = List<String>.from(eventSnapshot['favorites'] ?? []);
        if (favorites.contains(user.email)) {
          favorites.remove(user.email);
        } else {
          favorites.add(user.email!);
        }

        transaction.update(eventRef, {
          'favorites': favorites,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favorite Updated')));
    }
  }

  Future<void> _checkIn(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user's current location
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    DocumentReference eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
    DocumentSnapshot eventSnapshot = await eventRef.get();

    if (!eventSnapshot.exists) {
      throw Exception("Event does not exist!");
    }

    var eventData = eventSnapshot.data() as Map<String, dynamic>;
    GeoPoint eventLocation = eventData['location'];
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      eventLocation.latitude,
      eventLocation.longitude,
    );

    if (distance <= 804.672) { // half a mile in meters
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'checkedInUsers': FieldValue.arrayUnion([user.email]),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checked In Successfully')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You must be within half a mile of the event to check in')));
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Event Details', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventFormScreen(
                    isEdit: true,
                    eventId: eventId,
                    initialData: eventSnapshot.data() as Map<String, dynamic>,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          var eventData = snapshot.data!.data() as Map<String, dynamic>;
          bool isFavorite = eventData['favorites']?.contains(user?.email) ?? false;
          bool isRSVPed = eventData['rsvps']?.contains(user?.email) ?? false;
          bool isCheckedIn = eventData['checkedInUsers']?.contains(user?.email) ?? false;
          String createdBy = eventData['createdBy'] ?? 'Unknown';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eventData['name'], style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 16),
                Text('Created by: $createdBy', style: Theme.of(context).textTheme.bodyLarge),
                SizedBox(height: 16),
                Text('Description:', style: Theme.of(context).textTheme.titleMedium),
                Text(eventData['description']),
                SizedBox(height: 16),
                Text('Location:', style: Theme.of(context).textTheme.titleMedium),
                Text(eventData['location']),
                SizedBox(height: 16),
                Text('Start Time:', style: Theme.of(context).textTheme.titleMedium),
                Text(eventData['startTime'].toDate().toString()),
                SizedBox(height: 16),
                Text('End Time:', style: Theme.of(context).textTheme.titleMedium),
                Text(eventData['endTime'].toDate().toString()),
                SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text('RSVP', style: Theme.of(context).textTheme.titleMedium),
                      Switch(
                        value: isRSVPed,
                        onChanged: (value) => _toggleRSVP(context),
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: isCheckedIn ? null : () => _checkIn(context),
                        child: Text('Check In'),
                      ),
                      SizedBox(height: 16),
                      IconButton(
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.yellow : null),
                        onPressed: () => _toggleFavorite(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (isCheckedIn)
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to the team sign-up screen
                      },
                      child: Text('Sign Up for a Team'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
