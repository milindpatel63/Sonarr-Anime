import { filesize } from 'filesize';

function formatBytes(input: string | number) {
  const size = Number(input);

  if (isNaN(size)) {
    return '';
  }

  return `${filesize(size, {
    base: 2,
    round: 2,
  })}`;
}

export default formatBytes;
