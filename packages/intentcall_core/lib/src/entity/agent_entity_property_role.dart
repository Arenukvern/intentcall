enum AgentEntityPropertyRole {
  none,
  title,
  subtitle,
  keywords;

  static List<AgentEntityPropertyRole> get validValues => [
    title,
    subtitle,
    keywords,
  ];
}
