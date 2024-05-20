import { expect, test } from 'vitest';
import { render } from '@testing-library/react';

import Home from '../src/app/page';

test('render /', () => {
  render(<Home />);
});
