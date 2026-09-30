/// Short, resident facing facility name.
///
/// The records use the formal names the management system knows ("Fitness
/// Centre", "Rooftop BBQ") while the cards have always said "Gym" and
/// "BBQ Area". Kept in one place so the reservation screens, the facility
/// screens and the success page all read the same.
String displayFacilityName(String name) {
  return switch (name) {
    'Fitness Centre' => 'Gym',
    'Rooftop BBQ' => 'BBQ Area',
    _ => name,
  };
}
