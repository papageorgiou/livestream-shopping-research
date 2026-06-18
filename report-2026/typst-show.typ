#show: doc => report(
  title: [$title$],
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(by-author)$
  author: [$for(by-author)$$it.name.literal$$sep$, $endfor$],
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(abstract)$
  abstract: [$abstract$],
$endif$
  doc,
)
