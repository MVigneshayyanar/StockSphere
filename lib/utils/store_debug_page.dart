import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/firestore_service.dart';

/// Debug page to verify store-scoped access is working
class StoreDebugPage extends StatefulWidget {
  final String uid;

  const StoreDebugPage({super.key, required this.uid});

  @override
  State<StoreDebugPage> createState() => _StoreDebugPageState();
}

class _StoreDebugPageState extends State<StoreDebugPage> {
  String _status = 'Checking...';
  String _storeId = '';
  String _storePath = '';
  Map<String, dynamic> _storeData = {};

  @override
  void initState() {
    super.initState();
    _checkStoreAccess();
  }

  Future<void> _checkStoreAccess() async {
    try {
      // Test 1: Get Store ID
      final storeId = await FirestoreService().getCurrentStoreId();

      if (storeId == null) {
        setState(() {
          _status = '❌ ERROR: Could not get storeId';
        });
        return;
      }

      // Test 2: Get Store Document
      final storeDoc = await FirestoreService().getCurrentStoreDoc();

      if (storeDoc == null || !storeDoc.exists) {
        setState(() {
          _status = '❌ ERROR: Store document not found';
          _storeId = storeId;
        });
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;

      // Test 3: Try to access a collection
      final productsRef = await FirestoreService().getStoreCollection('products');
      final productsPath = productsRef.path;

      setState(() {
        _status = '✅ Store-scoped access working!';
        _storeId = storeId;
        _storePath = productsPath;
        _storeData = storeData;
      });

    } catch (e) {
      setState(() {
        _status = '❌ ERROR: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Debug'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                title: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_status, style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: const Text('Store ID', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_storeId.isEmpty ? 'Not found' : _storeId, style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: const Text('Products Path', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_storePath.isEmpty ? 'Not found' : _storePath, style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_storeData.isEmpty)
                      const Text('No data')
                    else
                      ..._storeData.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('${e.key}: ${e.value}', style: TextStyle(fontSize: 14)),
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkStoreAccess,
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 10),
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expected Behavior:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 8),
                    Text('✅ Store ID should show (e.g., 100001)', style: TextStyle(color: Colors.white)),
                    Text('✅ Products Path should show: store/100001/products', style: TextStyle(color: Colors.white)),
                    Text('✅ Store Data should show plan, businessName, etc.', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

