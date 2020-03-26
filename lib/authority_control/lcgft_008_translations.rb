def mus_008_composition_form_to_lcgft_term
  {
    'an' => 'Anthems',
    'bd' => 'Ballads',
    'bg' => 'Bluegrass music',
    'bl' => 'Blues (Music)',
    'ca' => 'Chaconnes',
    'cb' => 'Chants',
    'cc' => 'Chants',
    'cg' => 'Concerti grossi',
    'ch' => 'Chorales',
    'cl' => 'Chorale preludes',
    'co' => 'Concertos',
    'cp' => 'Polyphonic chansons',
    'cr' => 'Carols',
    'cs' => 'Aleatory music',
    'ct' => 'Cantatas',
    'cy' => 'Country music',
    'cz' => 'Canzonas (Instrumental music)',
    'df' => 'Dance music',
    'dv' => 'Suites',
    'fg' => 'Fugues',
    'fl' => 'Flamenco music',
    'fm' => 'Folk music',
    'ft' => 'Fantasias (Music)',
    'gm' => 'Gospel music',
    'hy' => 'Hymns',
    'jz' => 'Jazz',
    'mc' => 'Revues',
    'md' => 'Madrigals (Music)',
    'mi' => 'Minuets (Music)',
    'mo' => 'Motets',
    'mp' => 'Motion picture music',
    'mr' => 'Marches (Music)',
    'ms' => 'Masses',
    'mz' => 'Mazurkas (Music)',
    'nc' => 'Nocturnes (Music)',
    'op' => 'Operas',
    'or' => 'Oratorios',
    'ov' => 'Overtures',
    'pg' => 'Program music',
    'pm' => 'Lenten music',
    'po' => 'Polonaises (Music)',
    'pp' => 'Popular music',
    'pr' => 'Preludes (Music)',
    'ps' => 'Passacaglias',
    'pt' => 'Part songs',
    'pv' => 'Pavans (Music)',
    'rc' => 'Rock music',
    'rd' => 'Rondos',
    'rg' => 'Ragtime music',
    'ri' => 'Ricercars',
    'rp' => 'Rhapsodies (Music)',
    'rq' => 'Requiems',
    'sd' => 'Square dance music',
    'sg' => 'Songs',
    'sn' => 'Sonatas',
    'sp' => 'Symphonic poems',
    'st' => 'Studies (Music)',
    'su' => 'Suites',
    'sy' => 'Symphonies',
    'tc' => 'Toccatas',
    'vi' => 'Villancicos (Music)',
    'vr' => 'Variations (Music)',
    'wz' => 'Waltzes (Music)',
    'za' => 'Zarzuelas'
  }
end

def form_008_to_lcgft_term
  {
    'r' => 'Facsimiles',
    'f' => 'Braille books'
  }
end

def contents_to_lcgft_hash
  {
    'a' => 'Abstracts',
    'b' => 'Bibliographies',
    'c' => 'Catalogs',
    'd' => 'Dictionaries',
    'e' => 'Encyclopedias',
    'f' => 'Handbooks and manuals',
    'g' => 'Legislative materials',
    'i' => 'Indexes',
    'j' => 'Patents',
    'k' => 'Discographies',
    'l' => 'Legislative materials',
    'm' => 'Academic theses',
    'o' => 'Reviews',
    'p' => 'Programmed instructional materials',
    'q' => 'Filmographies',
    'r' => 'Directories',
    's' => 'Statistics',
    't' => 'Technical reports',
    'w' => 'Law digests',
    'y' => 'Yearbooks',
    'z' => 'Treaties',
    '5' => 'Calendars',
    '6' => 'Comics (Graphic works)'
  }
end

def book_cr_008_contents_to_lcgft_terms(contents)
  terms = []
  contents.each_char do |char|
    term = contents_to_lcgft_hash[char]
    terms << term if term
  end
  terms.uniq.sort
end

def book_lit_form_to_lcgft_hash
  {
    '1' => 'Fiction',
    'd' => 'Drama',
    'e' => 'Essays',
    'f' => 'Novels',
    'h' => 'Humor',
    'i' => 'Personal correspondence',
    'j' => 'Short stories',
    'p' => 'Poetry',
    's' => 'Speeches'
  }
end

def map_format_to_lcgft_hash
  {
    'e' => 'Manuscript maps',
    'j' => 'Postcards',
    'k' => 'Calendars',
    'l' => 'Puzzles and games',
    'n' => 'Puzzles and games',
    'o' => 'Wall maps',
    'p' => 'Playing cards'
  }
end

def map_formats_to_lcgft_terms(formats)
  terms = []
  formats.each_char do |char|
    term = map_format_to_lcgft_hash[char]
    terms << term if term
  end
  terms.uniq.sort
end

def visual_type_to_lcgft_hash
  {
    'c' => 'Facsimiles',
    'g' => 'Puzzles and games',
    'm' => 'Motion pictures',
    'v' => 'Video recordings'
  }
end
