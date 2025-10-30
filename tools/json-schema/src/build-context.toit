// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .resource-loader
import .store_
import .vocabulary show JSON-SCHEMA-2020-12-URI

class BuildContext:
  store/Store ::= Store
  refs/List := []  // Of ActionRef.
  discriminators/List ::= []  // Of [Discriminator, Schema].
  resource-loader/ResourceLoader
  /**
  Resource-schemas can be loaded through a URL that isn't their actual ID.
  For example, this can happen when a loaded schema defines its own "$id" property.
  */
  resource-uri-id-mapping := {:}  // From UriReference to UriReference.
  default-vocabulary-uri/string

  constructor
      --.resource-loader=HttpResourceLoader
      --.default-vocabulary-uri=JSON-SCHEMA-2020-12-URI:
