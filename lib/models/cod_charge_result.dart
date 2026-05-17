/// COD charge breakdown returned from the backend calculation API.
class CodChargeResult {
  const CodChargeResult({
    required this.weightCharge,
    required this.postalCharge,
    required this.totalCod,
  });

  final double weightCharge;
  final double postalCharge;
  final double totalCod;
}
