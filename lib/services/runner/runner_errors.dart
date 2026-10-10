/// Turns an error from the interpreter into something a learner can read.
///
/// Parse errors arrive with a dump of the whole program ("Problematic
/// code: [...]"), including the console I/O code DartLab adds itself. That
/// part is dropped; the message and its line number stay.
String friendlyRunError(Object error, {required String source}) {
  final raw = error.toString();
  final dump = raw.indexOf('Problematic code:');
  var message = (dump == -1 ? raw : raw.substring(0, dump)).trim();

  if (message.contains('await expression can only be used in an async function')) {
    message += source.contains('readLineSync')
        ? '\n\nTip: reading input is asynchronous in DartLab. Declare the '
            'function that calls stdin.readLineSync() as async (return type '
            'Future<...>) and call it with await.'
        : '\n\nTip: await can only be used inside a function marked async.';
  }
  return message;
}
